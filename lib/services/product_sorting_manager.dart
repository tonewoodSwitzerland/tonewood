// File: services/product_sorting_manager.dart
// Globaler Manager für die Sortierreihenfolge von Produkten in Dokumenten

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/icon_helper.dart';

/// Sortierungsmodus für Detail-Sortierung innerhalb einer Kategorie
enum DetailSortMode {
  byCode,      // Nach Code (10, 11, 12...)
  byNameAsc,   // Nach Name A→Z
  byNameDesc,  // Nach Name Z→A
  custom,      // Individuelle Reihenfolge
}

extension DetailSortModeExtension on DetailSortMode {
  String get displayName {
    switch (this) {
      case DetailSortMode.byCode:
        return 'Nach Code';
      case DetailSortMode.byNameAsc:
        return 'Alphabetisch (A→Z)';
      case DetailSortMode.byNameDesc:
        return 'Alphabetisch (Z→A)';
      case DetailSortMode.custom:
        return 'Individuelle Reihenfolge';
    }
  }

  String get displayNameEn {
    switch (this) {
      case DetailSortMode.byCode:
        return 'By Code';
      case DetailSortMode.byNameAsc:
        return 'Alphabetical (A→Z)';
      case DetailSortMode.byNameDesc:
        return 'Alphabetical (Z→A)';
      case DetailSortMode.custom:
        return 'Custom Order';
    }
  }

  IconData get icon {
    switch (this) {
      case DetailSortMode.byCode:
        return Icons.tag;
      case DetailSortMode.byNameAsc:
        return Icons.sort_by_alpha;
      case DetailSortMode.byNameDesc:
        return Icons.sort_by_alpha;
      case DetailSortMode.custom:
        return Icons.drag_handle;
    }
  }
}

class DetailSortSetting {
  final ProductSortCriteria criteria;
  final DetailSortMode mode;
  final List<String>? customOrder;
  final bool ascending; // NEU

  DetailSortSetting({
    required this.criteria,
    this.mode = DetailSortMode.byCode,
    this.customOrder,
    this.ascending = true, // Standardmäßig true
  });

  Map<String, dynamic> toMap() {
    return {
      'criteria': criteria.name,
      'mode': mode.name,
      'customOrder': customOrder,
      'ascending': ascending, // NEU
    };
  }

  factory DetailSortSetting.fromMap(Map<String, dynamic> map) {
    return DetailSortSetting(
      criteria: ProductSortCriteria.values.firstWhere(
            (e) => e.name == map['criteria'],
        orElse: () => ProductSortCriteria.wood,
      ),
      mode: DetailSortMode.values.firstWhere(
            (e) => e.name == map['mode'],
        orElse: () => DetailSortMode.byCode,
      ),
      customOrder: map['customOrder'] != null
          ? List<String>.from(map['customOrder'])
          : null,
      ascending: map['ascending'] ?? true, // NEU
    );
  }

  DetailSortSetting copyWith({
    ProductSortCriteria? criteria,
    DetailSortMode? mode,
    List<String>? customOrder,
    bool? ascending, // NEU
  }) {
    return DetailSortSetting(
      criteria: criteria ?? this.criteria,
      mode: mode ?? this.mode,
      customOrder: customOrder ?? this.customOrder,
      ascending: ascending ?? this.ascending, // NEU
    );
  }
}
/// Definiert die verfügbaren Sortierkriterien für Produkte
enum ProductSortCriteria {
  instrument,
  part,
  wood,
  quality,
}

/// Erweiterung für benutzerfreundliche Namen
extension ProductSortCriteriaExtension on ProductSortCriteria {
  String get displayName {
    switch (this) {
      case ProductSortCriteria.instrument:
        return 'Instrument';
      case ProductSortCriteria.part:
        return 'Bauteil';
      case ProductSortCriteria.wood:
        return 'Holzart';
      case ProductSortCriteria.quality:
        return 'Qualität';
    }
  }

  String get displayNameEn {
    switch (this) {
      case ProductSortCriteria.instrument:
        return 'Instrument';
      case ProductSortCriteria.part:
        return 'Part';
      case ProductSortCriteria.wood:
        return 'Wood Type';
      case ProductSortCriteria.quality:
        return 'Quality';
    }
  }

  /// Das Feld für den Code (zum Sortieren)
  String get codeField {
    switch (this) {
      case ProductSortCriteria.instrument:
        return 'instrument_code';
      case ProductSortCriteria.part:
        return 'part_code';
      case ProductSortCriteria.wood:
        return 'wood_code';
      case ProductSortCriteria.quality:
        return 'quality_code';
    }
  }

  /// Das Feld für den deutschen Namen
  String get nameField {
    switch (this) {
      case ProductSortCriteria.instrument:
        return 'instrument_name';
      case ProductSortCriteria.part:
        return 'part_name';
      case ProductSortCriteria.wood:
        return 'wood_name';
      case ProductSortCriteria.quality:
        return 'quality_name';
    }
  }

  /// Das Feld für den englischen Namen
  String get nameFieldEn {
    switch (this) {
      case ProductSortCriteria.instrument:
        return 'instrument_name_en';
      case ProductSortCriteria.part:
        return 'part_name_en';
      case ProductSortCriteria.wood:
        return 'wood_name_en';
      case ProductSortCriteria.quality:
        return 'quality_name_en';
    }
  }

  /// Die Firebase Collection für dieses Kriterium
  String get collectionName {
    switch (this) {
      case ProductSortCriteria.instrument:
        return 'instruments';
      case ProductSortCriteria.part:
        return 'parts';
      case ProductSortCriteria.wood:
        return 'wood_types';
      case ProductSortCriteria.quality:
        return 'qualities';
    }
  }

  IconData get icon {
    switch (this) {
      case ProductSortCriteria.instrument:
        return Icons.music_note;
      case ProductSortCriteria.part:
        return Icons.category;
      case ProductSortCriteria.wood:
        return Icons.forest;
      case ProductSortCriteria.quality:
        return Icons.star;
    }
  }

  String get iconName {
    switch (this) {
      case ProductSortCriteria.instrument:
        return 'music_note';
      case ProductSortCriteria.part:
        return 'category';
      case ProductSortCriteria.wood:
        return 'forest';
      case ProductSortCriteria.quality:
        return 'star';
    }
  }

  /// Ob dieses Kriterium als Gruppierung verwendet werden kann
  /// HINWEIS: Holzart ist IMMER die Gruppierung, andere können nicht gewählt werden
  bool get canBeGrouping {
    return this == ProductSortCriteria.wood;
  }
}

/// Repräsentiert eine einzelne Sortiereinstellung
class SortSetting {
  final ProductSortCriteria criteria;
  final bool ascending;
  final int priority; // 1 = höchste Priorität (primär), 4 = niedrigste

  SortSetting({
    required this.criteria,
    this.ascending = true,
    required this.priority,
  });

  Map<String, dynamic> toMap() {
    return {
      'criteria': criteria.name,
      'ascending': ascending,
      'priority': priority,
    };
  }

  factory SortSetting.fromMap(Map<String, dynamic> map) {
    return SortSetting(
      criteria: ProductSortCriteria.values.firstWhere(
            (e) => e.name == map['criteria'],
        orElse: () => ProductSortCriteria.instrument,
      ),
      ascending: map['ascending'] ?? true,
      priority: map['priority'] ?? 1,
    );
  }

  SortSetting copyWith({
    ProductSortCriteria? criteria,
    bool? ascending,
    int? priority,
  }) {
    return SortSetting(
      criteria: criteria ?? this.criteria,
      ascending: ascending ?? this.ascending,
      priority: priority ?? this.priority,
    );
  }
}

/// Hauptklasse für die Verwaltung der Produktsortierung
class ProductSortingManager {
  static const String _collection = 'settings';
  static const String _docId = 'product_sorting';
  static const String _detailDocId = 'product_sorting_details';

  // Cache für geladene Einstellungen
  static List<SortSetting>? _cachedSettings;
  static DateTime? _cacheTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  // Cache für Detail-Sortierungen
  static Map<ProductSortCriteria, DetailSortSetting>? _cachedDetailSettings;
  static DateTime? _detailCacheTime;

  /// Standard-Sortierreihenfolge
  /// HINWEIS: Holzart ist IMMER an Position 1 (Gruppierung)
  static List<SortSetting> get defaultSortSettings => [
    SortSetting(criteria: ProductSortCriteria.wood, priority: 1, ascending: true),
    SortSetting(criteria: ProductSortCriteria.instrument, priority: 2, ascending: true),
    SortSetting(criteria: ProductSortCriteria.part, priority: 3, ascending: true),
    SortSetting(criteria: ProductSortCriteria.quality, priority: 4, ascending: true),
  ];

  /// Gibt die sekundären Sortierkriterien zurück (ohne Holzart)
  static List<SortSetting> getSecondarySortSettings(List<SortSetting> allSettings) {
    return allSettings.where((s) => s.criteria != ProductSortCriteria.wood).toList();
  }

  /// Stellt sicher dass Holzart immer an Position 1 ist
  static List<SortSetting> ensureWoodFirst(List<SortSetting> settings) {
    final woodSetting = settings.firstWhere(
          (s) => s.criteria == ProductSortCriteria.wood,
      orElse: () => SortSetting(criteria: ProductSortCriteria.wood, priority: 1),
    );

    final otherSettings = settings
        .where((s) => s.criteria != ProductSortCriteria.wood)
        .toList();

    // Prioritäten neu zuweisen
    final result = <SortSetting>[
      woodSetting.copyWith(priority: 1),
    ];

    for (int i = 0; i < otherSettings.length; i++) {
      result.add(otherSettings[i].copyWith(priority: i + 2));
    }

    return result;
  }

  // ============================================================================
  // DETAIL-SORTIERUNG (innerhalb einer Kategorie)
  // ============================================================================

  /// Speichert die Detail-Sortierung für eine Kategorie
  static Future<void> saveDetailSortSetting(DetailSortSetting setting) async {
    try {
      await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_detailDocId)
          .set({
        setting.criteria.name: setting.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Cache invalidieren
      _cachedDetailSettings = null;
      _detailCacheTime = null;
    } catch (e) {
      print('Fehler beim Speichern der Detail-Sortierung: $e');
      rethrow;
    }
  }

  /// Lädt alle Detail-Sortierungen
  static Future<Map<ProductSortCriteria, DetailSortSetting>> loadAllDetailSortSettings() async {
    // Prüfe Cache
    if (_cachedDetailSettings != null && _detailCacheTime != null) {
      if (DateTime.now().difference(_detailCacheTime!) < _cacheDuration) {
        return _cachedDetailSettings!;
      }
    }

    final Map<ProductSortCriteria, DetailSortSetting> result = {};

    try {
      final doc = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_detailDocId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        for (final criteria in ProductSortCriteria.values) {
          if (data.containsKey(criteria.name)) {
            result[criteria] = DetailSortSetting.fromMap(
              Map<String, dynamic>.from(data[criteria.name]),
            );
          } else {
            // Standard-Einstellung
            result[criteria] = DetailSortSetting(criteria: criteria);
          }
        }
      } else {
        // Alle Standard-Einstellungen
        for (final criteria in ProductSortCriteria.values) {
          result[criteria] = DetailSortSetting(criteria: criteria);
        }
      }

      // Cache aktualisieren
      _cachedDetailSettings = result;
      _detailCacheTime = DateTime.now();

    } catch (e) {
      print('Fehler beim Laden der Detail-Sortierungen: $e');
      // Standard-Einstellungen zurückgeben
      for (final criteria in ProductSortCriteria.values) {
        result[criteria] = DetailSortSetting(criteria: criteria);
      }
    }

    return result;
  }

  /// Lädt die Detail-Sortierung für eine bestimmte Kategorie
  static Future<DetailSortSetting> loadDetailSortSetting(ProductSortCriteria criteria) async {
    final allSettings = await loadAllDetailSortSettings();
    return allSettings[criteria] ?? DetailSortSetting(criteria: criteria);
  }

  /// Lädt alle Einträge einer Kategorie aus Firebase
  static Future<List<Map<String, dynamic>>> loadCategoryItems(ProductSortCriteria criteria) async {
    String collectionName;
    switch (criteria) {
      case ProductSortCriteria.wood:
        collectionName = 'wood_types';
        break;
      case ProductSortCriteria.instrument:
        collectionName = 'instruments';
        break;
      case ProductSortCriteria.part:
        collectionName = 'parts';
        break;
      case ProductSortCriteria.quality:
        collectionName = 'qualities';
        break;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(collectionName)
          .orderBy('code')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Fehler beim Laden der Kategorie-Items: $e');
      return [];
    }
  }

  /// Sortiert Items einer Kategorie basierend auf den Detail-Einstellungen
  static Future<List<Map<String, dynamic>>> sortCategoryItems(
      List<Map<String, dynamic>> items,
      ProductSortCriteria criteria,
      ) async {
    final detailSetting = await loadDetailSortSetting(criteria);
    return sortCategoryItemsWithSetting(items, detailSetting);
  }

  /// Sortiert Items synchron mit gegebener Einstellung
  static List<Map<String, dynamic>> sortCategoryItemsWithSetting(
      List<Map<String, dynamic>> items,
      DetailSortSetting setting,
      ) {
    if (items.isEmpty) return items;

    final sortedList = List<Map<String, dynamic>>.from(items);

    switch (setting.mode) {
      case DetailSortMode.byCode:
        sortedList.sort((a, b) {
          final codeA = int.tryParse(a['code']?.toString() ?? '') ?? 0;
          final codeB = int.tryParse(b['code']?.toString() ?? '') ?? 0;
          int comp = codeA.compareTo(codeB);
          return setting.ascending ? comp : -comp; // Nutze das Feld aus dem Setting
        });
        break;

      case DetailSortMode.byNameAsc:
        sortedList.sort((a, b) {
          final nameA = a['name']?.toString().toLowerCase() ?? '';
          final nameB = b['name']?.toString().toLowerCase() ?? '';
          return nameA.compareTo(nameB);
        });
        break;

      case DetailSortMode.byNameDesc:
        sortedList.sort((a, b) {
          final nameA = a['name']?.toString().toLowerCase() ?? '';
          final nameB = b['name']?.toString().toLowerCase() ?? '';
          return nameB.compareTo(nameA);
        });
        break;

      case DetailSortMode.custom:
        if (setting.customOrder != null && setting.customOrder!.isNotEmpty) {
          sortedList.sort((a, b) {
            final codeA = a['code']?.toString() ?? '';
            final codeB = b['code']?.toString() ?? '';

            final indexA = setting.customOrder!.indexOf(codeA);
            final indexB = setting.customOrder!.indexOf(codeB);

            // Items die nicht in der custom order sind, kommen ans Ende
            final effectiveIndexA = indexA == -1 ? 999999 : indexA;
            final effectiveIndexB = indexB == -1 ? 999999 : indexB;

            return effectiveIndexA.compareTo(effectiveIndexB);
          });
        }
        break;
    }

    return sortedList;
  }

  /// Zeigt den Detail-Sortierungs-Dialog für eine Kategorie
  static Future<void> showDetailSortingDialog(
      BuildContext context,
      ProductSortCriteria criteria,
      ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DetailSortingDialog(criteria: criteria),
    );
  }

  // ============================================================================
  // HAUPT-SORTIERUNG (Kategorien-Reihenfolge)
  // ============================================================================

  /// Speichert die Sortiereinstellungen in Firestore
  static Future<void> saveSortSettings(List<SortSetting> settings) async {
    try {
      await FirebaseFirestore.instance.collection(_collection).doc(_docId).set({
        'sortSettings': settings.map((s) => s.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // Cache invalidieren
      _cachedSettings = null;
      _cacheTime = null;
    } catch (e) {
      print('Fehler beim Speichern der Sortiereinstellungen: $e');
      rethrow;
    }
  }

  /// Lädt die Sortiereinstellungen aus Firestore (mit Cache)
  static Future<List<SortSetting>> loadSortSettings() async {
    // Prüfe Cache
    if (_cachedSettings != null && _cacheTime != null) {
      if (DateTime.now().difference(_cacheTime!) < _cacheDuration) {
        return _cachedSettings!;
      }
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_docId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data.containsKey('sortSettings')) {
          final List<dynamic> settingsList = data['sortSettings'];
          final settings = settingsList
              .map((s) => SortSetting.fromMap(Map<String, dynamic>.from(s)))
              .toList()
            ..sort((a, b) => a.priority.compareTo(b.priority));

          // Cache aktualisieren
          _cachedSettings = settings;
          _cacheTime = DateTime.now();

          return settings;
        }
      }
    } catch (e) {
      print('Fehler beim Laden der Sortiereinstellungen: $e');
    }

    return defaultSortSettings;
  }

  /// Sortiert eine Liste von Produkten basierend auf den gespeicherten Einstellungen
  static Future<List<Map<String, dynamic>>> sortProducts(
      List<Map<String, dynamic>> products,
      ) async {
    final settings = await loadSortSettings();
    final detailSettings = await loadAllDetailSortSettings();
    return sortProductsWithAllSettings(products, settings, detailSettings);
  }

  /// Sortiert Produkte mit gegebenen Einstellungen (synchron, ohne Detail-Sortierung)
  static List<Map<String, dynamic>> sortProductsWithSettings(
      List<Map<String, dynamic>> products,
      List<SortSetting> settings,
      )
  {
    if (products.isEmpty || settings.isEmpty) return products;

    final sortedList = List<Map<String, dynamic>>.from(products);

    sortedList.sort((a, b) {
      for (final setting in settings) {
        final fieldName = setting.criteria.codeField;
        final valueA = a[fieldName]?.toString() ?? '';
        final valueB = b[fieldName]?.toString() ?? '';

        int comparison;

        // Versuche numerischen Vergleich
        final numA = int.tryParse(valueA);
        final numB = int.tryParse(valueB);

        if (numA != null && numB != null) {
          comparison = numA.compareTo(numB);
        } else {
          comparison = valueA.compareTo(valueB);
        }

        if (comparison != 0) {
          return setting.ascending ? comparison : -comparison;
        }
      }
      return 0;
    });

    return sortedList;
  }

  /// Sortiert Produkte mit Haupt- UND Detail-Sortierung
  static List<Map<String, dynamic>> sortProductsWithAllSettings(
      List<Map<String, dynamic>> products,
      List<SortSetting> settings,
      Map<ProductSortCriteria, DetailSortSetting> detailSettings,
      )
  {
    if (products.isEmpty || settings.isEmpty) return products;

    final sortedList = List<Map<String, dynamic>>.from(products);

    sortedList.sort((a, b) {
      for (final setting in settings) {
        final criteria = setting.criteria;
        final fieldName = criteria.codeField;
        final valueA = a[fieldName]?.toString() ?? '';
        final valueB = b[fieldName]?.toString() ?? '';

        int comparison;
        bool useAscendingSetting = true; // Ob ascending-Einstellung angewendet werden soll

        // Prüfe ob es eine Detail-Sortierung für dieses Kriterium gibt
        final detailSetting = detailSettings[criteria];

        if (detailSetting != null && detailSetting.mode == DetailSortMode.custom &&
            detailSetting.customOrder != null && detailSetting.customOrder!.isNotEmpty) {
          // Custom Order verwenden - ascending wird IGNORIERT
          final indexA = detailSetting.customOrder!.indexOf(valueA);
          final indexB = detailSetting.customOrder!.indexOf(valueB);

          final effectiveIndexA = indexA == -1 ? 999999 : indexA;
          final effectiveIndexB = indexB == -1 ? 999999 : indexB;

          comparison = effectiveIndexA.compareTo(effectiveIndexB);
          useAscendingSetting = false; // Custom = feste Reihenfolge, nicht invertieren
        } else if (detailSetting != null && detailSetting.mode == DetailSortMode.byNameAsc) {
          // Nach Name aufsteigend - ascending wird IGNORIERT (ist schon in byNameAsc definiert)
          final nameA = a[criteria.nameField]?.toString().toLowerCase() ?? valueA;
          final nameB = b[criteria.nameField]?.toString().toLowerCase() ?? valueB;
          comparison = nameA.compareTo(nameB);
          useAscendingSetting = false;
        } else if (detailSetting != null && detailSetting.mode == DetailSortMode.byNameDesc) {
          // Nach Name absteigend - ascending wird IGNORIERT (ist schon in byNameDesc definiert)
          final nameA = a[criteria.nameField]?.toString().toLowerCase() ?? valueA;
          final nameB = b[criteria.nameField]?.toString().toLowerCase() ?? valueB;
          comparison = nameB.compareTo(nameA);
          useAscendingSetting = false;
        } else {
          // Standard: Nach Code
          final numA = int.tryParse(valueA);
          final numB = int.tryParse(valueB);

          comparison = (numA != null && numB != null)
              ? numA.compareTo(numB)
              : valueA.compareTo(valueB);

          // Nutze die Richtung aus dem Detail-Setting statt der globalen Einstellung
          final isAsc = detailSetting?.ascending ?? true;
          if (!isAsc) comparison = -comparison;

          useAscendingSetting = false; // Wir haben die Richtung bereits oben angewendet
        }

        if (comparison != 0) {
          // Nur bei byCode wird die ascending-Einstellung angewendet
          if (useAscendingSetting) {
            return setting.ascending ? comparison : -comparison;
          } else {
            return comparison;
          }
        }
      }
      return 0;
    });

    return sortedList;
  }

  /// Gruppiert und sortiert Produkte nach dem primären Sortierkriterium
  /// Gibt eine Map zurück mit dem Gruppennamen als Key und den Items als Value
  ///
  /// Beispiel: Wenn "Holzart" primär ist, werden die Produkte nach Holzart gruppiert
  /// und innerhalb jeder Gruppe nach den sekundären Kriterien sortiert
  static Future<Map<String, List<Map<String, dynamic>>>> groupAndSortProducts(
      List<Map<String, dynamic>> products,
      String language, {
        Future<Map<String, dynamic>?> Function(String code, ProductSortCriteria criteria)?
        getAdditionalInfo,
      }) async {
    if (products.isEmpty) return {};

    final settings = await loadSortSettings();
    final detailSettings = await loadAllDetailSortSettings(); // NEU: Detail-Einstellungen laden
    if (settings.isEmpty) return {'': products};

    // Das primäre Kriterium bestimmt die Gruppierung (immer Holzart)
    final primarySetting = settings.first;
    final primaryCriteria = primarySetting.criteria;
    final primaryDetailSetting = detailSettings[primaryCriteria];

    // Cache für zusätzliche Infos (z.B. lateinische Namen)
    final Map<String, Map<String, dynamic>> infoCache = {};

    // Gruppiere nach primärem Kriterium
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    final Map<String, String> groupKeyToCode = {}; // Um Code für Sortierung zu speichern

    for (final item in products) {
      final code = item[primaryCriteria.codeField]?.toString() ?? '';

      // Lade zusätzliche Infos wenn Callback vorhanden
      if (!infoCache.containsKey(code) && getAdditionalInfo != null) {
        infoCache[code] = await getAdditionalInfo(code, primaryCriteria) ?? {};
      }

      final additionalInfo = infoCache[code] ?? {};

      // Erstelle Gruppennamen basierend auf Sprache
      String groupName;
      if (language == 'EN') {
        groupName = additionalInfo['name_english'] ??
            item[primaryCriteria.nameFieldEn] ??
            item[primaryCriteria.nameField] ??
            code;
      } else {
        groupName = additionalInfo['name'] ??
            item[primaryCriteria.nameField] ??
            code;
      }

      // Füge lateinischen Namen hinzu wenn vorhanden (für Holzarten)
      if (primaryCriteria == ProductSortCriteria.wood) {
        final latinName = additionalInfo['name_latin'] ?? '';
        if (latinName.isNotEmpty) {
          groupName = '$groupName\n($latinName)';
        }
      }

      if (!grouped.containsKey(groupName)) {
        grouped[groupName] = [];
        groupKeyToCode[groupName] = code;
      }

      // Erweitere Item mit Display-Infos
      final enhancedItem = Map<String, dynamic>.from(item);
      enhancedItem['_group_display_name'] = groupName;
      enhancedItem['_group_code'] = code;

      grouped[groupName]!.add(enhancedItem);
    }

    // Sortiere Items innerhalb jeder Gruppe nach den restlichen Kriterien MIT Detail-Einstellungen
    final secondarySettings = settings.skip(1).toList();

    grouped.forEach((key, items) {
      // NEU: Verwende sortProductsWithAllSettings statt sortProductsWithSettings
      grouped[key] = sortProductsWithAllSettings(items, secondarySettings, detailSettings);
    });

    // Sortiere die Gruppen selbst basierend auf Detail-Einstellung der Holzart
    final sortedKeys = grouped.keys.toList();

    // Prüfe ob Custom-Order für primäres Kriterium (Holzart) existiert
    if (primaryDetailSetting != null &&
        primaryDetailSetting.mode == DetailSortMode.custom &&
        primaryDetailSetting.customOrder != null &&
        primaryDetailSetting.customOrder!.isNotEmpty) {
      // Custom Order für Gruppen
      sortedKeys.sort((a, b) {
        final codeA = groupKeyToCode[a] ?? '';
        final codeB = groupKeyToCode[b] ?? '';

        final indexA = primaryDetailSetting.customOrder!.indexOf(codeA);
        final indexB = primaryDetailSetting.customOrder!.indexOf(codeB);

        final effectiveIndexA = indexA == -1 ? 999999 : indexA;
        final effectiveIndexB = indexB == -1 ? 999999 : indexB;

        return effectiveIndexA.compareTo(effectiveIndexB);
      });
    } else if (primaryDetailSetting != null &&
        primaryDetailSetting.mode == DetailSortMode.byNameAsc) {
      // Nach Name aufsteigend
      sortedKeys.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    } else if (primaryDetailSetting != null &&
        primaryDetailSetting.mode == DetailSortMode.byNameDesc) {
      // Nach Name absteigend
      sortedKeys.sort((a, b) => b.toLowerCase().compareTo(a.toLowerCase()));
    } else {
      // Standard: Nach Code mit ascending-Einstellung
      sortedKeys.sort((a, b) {
        final codeA = groupKeyToCode[a] ?? '';
        final codeB = groupKeyToCode[b] ?? '';

        final numA = int.tryParse(codeA);
        final numB = int.tryParse(codeB);

        int comparison;
        if (numA != null && numB != null) {
          comparison = numA.compareTo(numB);
        } else {
          comparison = codeA.compareTo(codeB);
        }

        final isAsc = primaryDetailSetting?.ascending ?? true;
        return isAsc ? comparison : -comparison;
      });
    }

    // Erstelle sortierte Map
    final Map<String, List<Map<String, dynamic>>> sortedGrouped = {};
    for (final key in sortedKeys) {
      sortedGrouped[key] = grouped[key]!;
    }

    return sortedGrouped;
  }

  /// Hilfsmethode zum Laden von Holzart-Infos aus Firebase
  static Future<Map<String, dynamic>?> getWoodTypeInfo(String woodCode) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('wood_types')
          .doc(woodCode)
          .get();

      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      print('Fehler beim Laden der Holzart-Info: $e');
    }
    return null;
  }

  /// Hilfsmethode zum Laden von Instrument-Infos aus Firebase
  static Future<Map<String, dynamic>?> getInstrumentInfo(String code) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('instruments')
          .doc(code)
          .get();

      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      print('Fehler beim Laden der Instrument-Info: $e');
    }
    return null;
  }

  /// Hilfsmethode zum Laden von Part-Infos aus Firebase
  static Future<Map<String, dynamic>?> getPartInfo(String code) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('parts')
          .doc(code)
          .get();

      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      print('Fehler beim Laden der Part-Info: $e');
    }
    return null;
  }

  /// Hilfsmethode zum Laden von Qualitäts-Infos aus Firebase
  static Future<Map<String, dynamic>?> getQualityInfo(String code) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('qualities')
          .doc(code)
          .get();

      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      print('Fehler beim Laden der Qualitäts-Info: $e');
    }
    return null;
  }

  /// Generische Methode zum Laden von Infos basierend auf Kriterium
  static Future<Map<String, dynamic>?> getInfoForCriteria(
      String code,
      ProductSortCriteria criteria,
      ) async {
    switch (criteria) {
      case ProductSortCriteria.wood:
        return getWoodTypeInfo(code);
      case ProductSortCriteria.instrument:
        return getInstrumentInfo(code);
      case ProductSortCriteria.part:
        return getPartInfo(code);
      case ProductSortCriteria.quality:
        return getQualityInfo(code);
    }
  }

  /// Zeigt den Sortierungs-Dialog
  static Future<void> showSortingDialog(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ProductSortingDialog(),
    );
  }

  /// Erstellt einen Button für die Sortiereinstellungen
  static Widget buildSortingButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => showSortingDialog(context),
      icon: getAdaptiveIcon(
        iconName: 'sort',
        defaultIcon: Icons.sort,
      ),
      label: const Text('Sortierreihenfolge'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  /// Gibt eine lesbare Beschreibung der aktuellen Sortierung zurück
  static Future<String> getSortingDescription({String language = 'DE'}) async {
    final settings = await loadSortSettings();

    final parts = settings.map((s) {
      final name = language == 'EN'
          ? s.criteria.displayNameEn
          : s.criteria.displayName;
      final direction = s.ascending
          ? (language == 'EN' ? '↑' : '↑')
          : (language == 'EN' ? '↓' : '↓');
      return '$name $direction';
    }).toList();

    return parts.join(' → ');
  }
}

/// Dialog-Widget für die Sortiereinstellungen
class _ProductSortingDialog extends StatefulWidget {
  const _ProductSortingDialog({Key? key}) : super(key: key);

  @override
  State<_ProductSortingDialog> createState() => _ProductSortingDialogState();
}

class _ProductSortingDialogState extends State<_ProductSortingDialog> {
  List<SortSetting> _sortSettings = [];
  List<SortSetting> _secondarySettings = []; // Nur die sekundären (ohne Holzart)
  SortSetting? _woodSetting; // Holzart separat
  bool _isLoading = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await ProductSortingManager.loadSortSettings();
    setState(() {
      _sortSettings = ProductSortingManager.ensureWoodFirst(settings);
      _woodSetting = _sortSettings.firstWhere(
            (s) => s.criteria == ProductSortCriteria.wood,
      );
      _secondarySettings = _sortSettings
          .where((s) => s.criteria != ProductSortCriteria.wood)
          .toList();
      _isLoading = false;
    });
  }

  void _onReorderSecondary(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _secondarySettings.removeAt(oldIndex);
      _secondarySettings.insert(newIndex, item);

      // Prioritäten neu zuweisen (Holzart ist immer 1)
      for (int i = 0; i < _secondarySettings.length; i++) {
        _secondarySettings[i] = _secondarySettings[i].copyWith(priority: i + 2);
      }

      // Gesamt-Settings aktualisieren
      _sortSettings = [
        _woodSetting!.copyWith(priority: 1),
        ..._secondarySettings,
      ];

      _hasChanges = true;
    });
  }

  void _toggleSortDirection(int index, {bool isWood = false}) {
    setState(() {
      if (isWood) {
        _woodSetting = _woodSetting!.copyWith(ascending: !_woodSetting!.ascending);
        _sortSettings[0] = _woodSetting!;
      } else {
        _secondarySettings[index] = _secondarySettings[index].copyWith(
          ascending: !_secondarySettings[index].ascending,
        );
        _sortSettings = [
          _woodSetting!,
          ..._secondarySettings,
        ];
      }
      _hasChanges = true;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      await ProductSortingManager.saveSortSettings(_sortSettings);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sortiereinstellungen gespeichert'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resetToDefault() {
    setState(() {
      _sortSettings = ProductSortingManager.defaultSortSettings;
      _woodSetting = _sortSettings.first;
      _secondarySettings = _sortSettings.skip(1).toList();
      _hasChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: getAdaptiveIcon(
                    iconName: 'sort',
                    defaultIcon: Icons.sort,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sortierreihenfolge',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Für alle Dokumente',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: getAdaptiveIcon(
                    iconName: 'close',
                    defaultIcon: Icons.close,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SEKTION 1: Gruppierung (Holzart - fixiert)
                  _buildSectionHeader(
                    context,
                    'Gruppierung',
                    'Produkte werden nach Holzart gruppiert',
                    Icons.folder_outlined,
                    'folder',
                  ),
                  const SizedBox(height: 12),

                  // Holzart Card (fixiert, nicht verschiebbar)
                  if (_woodSetting != null)
                    _buildFixedWoodItem(_woodSetting!),

                  const SizedBox(height: 24),

                  // SEKTION 2: Sortierung innerhalb der Gruppen
                  _buildSectionHeader(
                    context,
                    'Sortierung innerhalb der Gruppen',
                    'Reihenfolge der Produkte innerhalb jeder Holzart',
                    Icons.swap_vert,
                    'swap_vert',
                  ),
                  const SizedBox(height: 12),

                  // Info für Drag & Drop
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        getAdaptiveIcon(
                          iconName: 'drag_handle',
                          defaultIcon: Icons.drag_handle,
                          color: Theme.of(context).colorScheme.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ziehe die Kriterien in die gewünschte Reihenfolge',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Sekundäre Sortierkriterien (sortierbar)
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _secondarySettings.length,
                    onReorder: _onReorderSecondary,
                    proxyDecorator: (child, index, animation) {
                      return Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      final setting = _secondarySettings[index];
                      return _buildSecondarySortItem(setting, index);
                    },
                  ),

                  const SizedBox(height: 16),

                  // Legende
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem(
                        context,
                        Icons.arrow_upward,
                        'Aufsteigend (A→Z, 10→99)',
                      ),
                      const SizedBox(width: 24),
                      _buildLegendItem(
                        context,
                        Icons.arrow_downward,
                        'Absteigend (Z→A, 99→10)',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Reset Button
                  TextButton.icon(
                    onPressed: _resetToDefault,
                    icon: getAdaptiveIcon(
                      iconName: 'restore',
                      defaultIcon: Icons.restore,
                      size: 18,
                    ),
                    label: const Text('Standard'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  const Spacer(),
                  // Cancel Button
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Abbrechen'),
                  ),
                  const SizedBox(width: 12),
                  // Save Button
                  ElevatedButton.icon(
                    onPressed: _hasChanges ? _saveSettings : null,
                    icon: _isLoading
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : getAdaptiveIcon(
                      iconName: 'save',
                      defaultIcon: Icons.save,
                      size: 18,
                    ),
                    label: const Text('Speichern'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context,
      String title,
      String subtitle,
      IconData icon,
      String iconName,
      ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: getAdaptiveIcon(
            iconName: iconName,
            defaultIcon: icon,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Fixierte Holzart-Karte (nicht verschiebbar)
  Widget _buildFixedWoodItem(SortSetting setting) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Position 1 Badge
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  '1',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: getAdaptiveIcon(
                iconName: 'forest',
                defaultIcon: Icons.forest,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Text(
              'Holzart',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'FIXIERT',
                style: TextStyle(
                  fontSize: 9,
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        // Ersetze den subtitle Block in _buildFixedWoodItem mit diesem Code:
        subtitle: FutureBuilder<DetailSortSetting>(
          future: ProductSortingManager.loadDetailSortSetting(ProductSortCriteria.wood),
          builder: (context, snapshot) {
            final detailSetting = snapshot.data;
            final detailMode = detailSetting?.mode ?? DetailSortMode.byCode;
            // Wir nutzen hier direkt das Feld aus dem geladenen Detail-Setting
            final isAsc = detailSetting?.ascending ?? true;

            String modeText;
            if (detailMode == DetailSortMode.custom) {
              modeText = 'Individuell';
            } else if (detailMode == DetailSortMode.byNameAsc) {
              modeText = 'Alphabetisch (A→Z)';
            } else if (detailMode == DetailSortMode.byNameDesc) {
              modeText = 'Alphabetisch (Z→A)';
            } else {
              // Nutze isAsc statt setting.ascending
              modeText = isAsc ? 'Nach Code (aufsteigend)' : 'Nach Code (absteigend)';
            }
            return Text(
              modeText,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            );
          },
        ),
        trailing: FutureBuilder<DetailSortSetting>(
          future: ProductSortingManager.loadDetailSortSetting(ProductSortCriteria.wood),
          builder: (context, snapshot) {
            final detailMode = snapshot.data?.mode ?? DetailSortMode.byCode;
            final isCustomOrName = detailMode == DetailSortMode.custom ||
                detailMode == DetailSortMode.byNameAsc ||
                detailMode == DetailSortMode.byNameDesc;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Detail-Sortierung Button
                IconButton(
                  onPressed: () => ProductSortingManager.showDetailSortingDialog(
                    context,
                    ProductSortCriteria.wood,
                  ),
                  icon: getAdaptiveIcon(
                    iconName: 'tune',
                    defaultIcon: Icons.tune,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 20,
                  ),
                  tooltip: 'Holzarten sortieren',
                ),
                // Sortierrichtung Toggle - nur bei byCode relevant

              ],
            );
          },
        ),
      ),
    );
  }

  /// Sekundäre Sortierkriterien (verschiebbar)
  Widget _buildSecondarySortItem(SortSetting setting, int index) {
    final criteria = setting.criteria;

    return Container(
      key: ValueKey(criteria),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Prioritätsnummer (2, 3, 4)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _getSecondaryPriorityColor(index),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${index + 2}', // +2 weil Holzart Position 1 ist
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: getAdaptiveIcon(
                iconName: criteria.iconName,
                defaultIcon: criteria.icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
          ],
        ),
        title: Text(
          criteria.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: FutureBuilder<DetailSortSetting>(
          future: ProductSortingManager.loadDetailSortSetting(criteria),
          builder: (context, snapshot) {
            final detailSetting = snapshot.data;
            final detailMode = detailSetting?.mode ?? DetailSortMode.byCode;
            final isAsc = detailSetting?.ascending ?? true; // <--- NEU: Aus Detail lesen

            String modeText;
            if (detailMode == DetailSortMode.custom) {
              modeText = 'Individuell';
            } else if (detailMode == DetailSortMode.byNameAsc) {
              modeText = 'Alphabetisch (A→Z)';
            } else if (detailMode == DetailSortMode.byNameDesc) {
              modeText = 'Alphabetisch (Z→A)';
            } else {
              // Nutze isAsc statt setting.ascending
              modeText = isAsc ? 'Nach Code (aufsteigend)' : 'Nach Code (absteigend)';
            }
            return Text(modeText, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)));
          },
        ),
        trailing: FutureBuilder<DetailSortSetting>(
          future: ProductSortingManager.loadDetailSortSetting(criteria),
          builder: (context, snapshot) {
            final detailMode = snapshot.data?.mode ?? DetailSortMode.byCode;
            final isCustomOrName = detailMode == DetailSortMode.custom ||
                detailMode == DetailSortMode.byNameAsc ||
                detailMode == DetailSortMode.byNameDesc;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Detail-Sortierung Button
                IconButton(
                  onPressed: () => ProductSortingManager.showDetailSortingDialog(
                    context,
                    criteria,
                  ),
                  icon: getAdaptiveIcon(
                    iconName: 'tune',
                    defaultIcon: Icons.tune,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 20,
                  ),
                  tooltip: '${criteria.displayName} sortieren',
                ),

                // Drag Handle
                ReorderableDragStartListener(
                  index: index,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: getAdaptiveIcon(
                      iconName: 'drag_handle',
                      defaultIcon: Icons.drag_handle,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Color _getSecondaryPriorityColor(int index) {
    switch (index) {
      case 0:
        return Colors.blue.shade500;
      case 1:
        return Colors.blue.shade400;
      case 2:
        return Colors.blue.shade300;
      default:
        return Colors.grey;
    }
  }

}

Widget _buildLegendItem(BuildContext context, IconData icon, String text) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon,
          size: 14,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
      const SizedBox(width: 4),
      Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        ),
      ),
    ],
  );
}


/// Dialog für Detail-Sortierung innerhalb einer Kategorie
class _DetailSortingDialog extends StatefulWidget {
  final ProductSortCriteria criteria;

  const _DetailSortingDialog({
    Key? key,
    required this.criteria,
  }) : super(key: key);

  @override
  State<_DetailSortingDialog> createState() => _DetailSortingDialogState();
}

class _DetailSortingDialogState extends State<_DetailSortingDialog> {
  DetailSortSetting? _setting;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _sortedItems = [];
  bool _isLoading = true;
  bool _hasChanges = false;
  DetailSortMode _selectedMode = DetailSortMode.byCode;
  bool _isAscending = true; // Neu hinzugefügt
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Lade aktuelle Einstellung
      final setting = await ProductSortingManager.loadDetailSortSetting(widget.criteria);

      // Lade alle Items der Kategorie
      final items = await ProductSortingManager.loadCategoryItems(widget.criteria);

      setState(() {
        _setting = setting;
        _selectedMode = setting.mode;
        _isAscending = setting.ascending; // Hier den gespeicherten Wert laden!
        _items = items;

        // Sortiere Items basierend auf aktueller Einstellung
        if (setting.mode == DetailSortMode.custom &&
            setting.customOrder != null &&
            setting.customOrder!.isNotEmpty) {
          _sortedItems = _applyCustomOrder(items, setting.customOrder!);
        } else {
          _sortedItems = List.from(items);
          _applySortMode(_selectedMode);
        }

        _isLoading = false;
      });
    } catch (e) {
      print('Fehler beim Laden: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _applyCustomOrder(
      List<Map<String, dynamic>> items,
      List<String> customOrder,
      ) {
    final result = List<Map<String, dynamic>>.from(items);
    result.sort((a, b) {
      final codeA = a['code']?.toString() ?? '';
      final codeB = b['code']?.toString() ?? '';

      final indexA = customOrder.indexOf(codeA);
      final indexB = customOrder.indexOf(codeB);

      final effectiveIndexA = indexA == -1 ? 999999 : indexA;
      final effectiveIndexB = indexB == -1 ? 999999 : indexB;

      return effectiveIndexA.compareTo(effectiveIndexB);
    });
    return result;
  }

  void _applySortMode(DetailSortMode mode) {
    setState(() {
      _selectedMode = mode;
      _hasChanges = true;

      switch (mode) {
        case DetailSortMode.byCode:
          _sortedItems.sort((a, b) {
            final codeA = int.tryParse(a['code']?.toString() ?? '') ?? 0;
            final codeB = int.tryParse(b['code']?.toString() ?? '') ?? 0;
            return _isAscending ? codeA.compareTo(codeB) : codeB.compareTo(codeA);
          });
          break;
        case DetailSortMode.byNameAsc:
          _sortedItems.sort((a, b) {
            final nameA = a['name']?.toString().toLowerCase() ?? '';
            final nameB = b['name']?.toString().toLowerCase() ?? '';
            return nameA.compareTo(nameB);
          });
          break;
        case DetailSortMode.byNameDesc:
          _sortedItems.sort((a, b) {
            final nameA = a['name']?.toString().toLowerCase() ?? '';
            final nameB = b['name']?.toString().toLowerCase() ?? '';
            return nameB.compareTo(nameA);
          });
          break;
        case DetailSortMode.custom:
        // Bei custom: bestehende Reihenfolge beibehalten
          break;
      }
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (_selectedMode != DetailSortMode.custom) {
      // Automatisch auf custom umschalten wenn der User etwas zieht
      setState(() {
        _selectedMode = DetailSortMode.custom;
      });
    }

    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _sortedItems.removeAt(oldIndex);
      _sortedItems.insert(newIndex, item);
      _hasChanges = true;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);

    try {
      List<String>? customOrder;

      if (_selectedMode == DetailSortMode.custom) {
        customOrder = _sortedItems.map((item) => item['code'].toString()).toList();
      }

      final newSetting = DetailSortSetting(
        criteria: widget.criteria,
        mode: _selectedMode,
        customOrder: customOrder,
        ascending: _isAscending, // Hier den aktuellen UI-Status mitschicken!
      );

      await ProductSortingManager.saveDetailSortSetting(newSetting);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.criteria.displayName}-Sortierung gespeichert'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: getAdaptiveIcon(
                    iconName: widget.criteria.iconName,
                    defaultIcon: widget.criteria.icon,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.criteria.displayName} sortieren',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_items.length} Einträge',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: getAdaptiveIcon(
                    iconName: 'close',
                    defaultIcon: Icons.close,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Sortier-Modus Auswahl
          Padding(
            padding: const EdgeInsets.all(16),
            child:
            // Innerhalb von build() im _DetailSortingDialog:
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sortierung',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row( // Row für Modus und Richtung nebeneinander
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Linke Seite: Modi
                    Expanded(
                      flex: 3,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: DetailSortMode.values.map((mode) {
                          final isSelected = _selectedMode == mode;
                          return FilterChip(
                            selected: isSelected,
                            label: Text(mode.displayName),
                            onSelected: (selected) {
                              if (selected) _applySortMode(mode);
                            },
                          );
                        }).toList(),
                      ),
                    ),

                    // Rechte Seite: Richtung (Nur bei "Nach Code" relevant)
                    if (_selectedMode == DetailSortMode.byCode)
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            const Text('Richtung', style: TextStyle(fontSize: 11)),
                            const SizedBox(height: 4),
                            IconButton.filledTonal(
                              onPressed: () {
                                setState(() {
                                  _isAscending = !_isAscending;
                                  _hasChanges = true;
                                  _applySortMode(_selectedMode); // Liste neu sortieren
                                });
                              },
                              icon: Icon(_isAscending ? Icons.arrow_upward : Icons.arrow_downward),
                              tooltip: _isAscending ? 'Aufsteigend' : 'Absteigend',
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Hinweis für Custom Mode
          if (_selectedMode == DetailSortMode.custom)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    getAdaptiveIcon(
                      iconName: 'drag_handle',
                      defaultIcon: Icons.drag_handle,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ziehe die Einträge in die gewünschte Reihenfolge',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Items Liste
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedMode == DetailSortMode.custom
                ? ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _sortedItems.length,
              onReorder: _onReorder,
              proxyDecorator: (child, index, animation) {
                return Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final item = _sortedItems[index];
                return _buildItemTile(item, index, true);
              },
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _sortedItems.length,
              itemBuilder: (context, index) {
                final item = _sortedItems[index];
                return _buildItemTile(item, index, false);
              },
            ),
          ),

          // Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Abbrechen'),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _hasChanges ? _saveSettings : null,
                    icon: _isLoading
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : getAdaptiveIcon(
                      iconName: 'save',
                      defaultIcon: Icons.save,
                      size: 18,
                    ),
                    label: const Text('Speichern'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(Map<String, dynamic> item, int index, bool isDraggable) {
    final code = item['code']?.toString() ?? '';
    final name = item['name']?.toString() ?? '';
    final short = item['short']?.toString() ?? '';
    final nameEnglish = item['name_english']?.toString() ?? '';
    final nameLatin = item['name_latin']?.toString() ?? '';

    return Container(
      key: ValueKey(code),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Position (nur bei custom)
            if (isDraggable)
              Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            // Code
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                code,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Row(
          children: [
            if (short.isNotEmpty) ...[
              Text(
                short,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              if (nameEnglish.isNotEmpty || nameLatin.isNotEmpty)
                Text(
                  ' • ',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
            ],
            if (nameEnglish.isNotEmpty)
              Flexible(
                child: Text(
                  nameEnglish,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (nameLatin.isNotEmpty && nameEnglish.isEmpty)
              Flexible(
                child: Text(
                  nameLatin,
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        trailing: isDraggable
            ? ReorderableDragStartListener(
          index: index,
          child: Container(
            padding: const EdgeInsets.all(8),
            child: getAdaptiveIcon(
              iconName: 'drag_handle',
              defaultIcon: Icons.drag_handle,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        )
            : null,
      ),
    );
  }
}