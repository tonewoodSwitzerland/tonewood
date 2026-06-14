/// Zentrales Filtermodell für den WarehouseScreen (Lager + Online-Shop).
///
/// Hält den kompletten Filterzustand an EINER Stelle und kümmert sich um die
/// Serialisierung (gespeicherte Filter + Favoriten). Die fünf
/// Shop-Eigenschaften (thermo, hasel, mondholz, fsc liegen im verschachtelten
/// `features`-Map, `is_acts` ist ein Top-Level-Feld) sowie der Jahrgang `year`
/// gelten NUR für die Shop-Ansicht und werden clientseitig nachgefiltert
/// (siehe [WarehouseFilterQuery]). Der Von-Bis-Datumsfilter (`createdFrom` /
/// `createdTo`) wirkt auf das Feld `created_at` und gilt für Lager UND Shop;
/// er wird ebenfalls clientseitig angewendet.
class WarehouseFilter {
  // --- Server-seitig (Firestore-Query) ---
  final List<String> instrumentCodes;
  final List<String> partCodes;
  final List<String> woodCodes;
  final List<String> qualityCodes;
  final String? unit;
  final bool isOnlineShopView;
  final String? shopFilter; // null | 'available' | 'sold' | 'discounted'

  // --- Client-seitig: Textsuche (Lager + Shop) ---
  final String searchText;

  // --- Client-seitig: Von-Bis-Datum auf `created_at` (Lager + Shop) ---
  /// Untere Grenze (inklusive, ab Tagesbeginn). null = keine untere Grenze.
  final DateTime? createdFrom;

  /// Obere Grenze (inklusive, bis Tagesende). null = keine obere Grenze.
  final DateTime? createdTo;

  // --- Client-seitig, NUR Shop ---
  /// Teilmenge von [featureKeys]. Jedes gewählte Merkmal muss true sein (UND).
  final Set<String> features;

  /// null = egal, true/false = `is_acts` muss exakt diesem Wert entsprechen.
  final bool? isActs;

  /// Ausgewählte Jahrgänge. `year` ist im Schema ein String (z. B. "07").
  final List<String> years;

  const WarehouseFilter({
    this.instrumentCodes = const [],
    this.partCodes = const [],
    this.woodCodes = const [],
    this.qualityCodes = const [],
    this.unit,
    this.isOnlineShopView = false,
    this.shopFilter,
    this.searchText = '',
    this.createdFrom,
    this.createdTo,
    this.features = const {},
    this.isActs,
    this.years = const [],
  });

  /// Schlüssel der vier Boolean-Merkmale im `features`-Map eines Shop-Dokuments.
  static const List<String> featureKeys = ['thermo', 'hasel', 'mondholz', 'fsc'];

  bool get hasSearch => searchText.trim().isNotEmpty;

  /// Ist ein Von-Bis-Datumsfilter aktiv?
  bool get hasDateFilter => createdFrom != null || createdTo != null;

  /// Irgendein Filter aktiv? (für Badge / "Aktive Filter"-Bereich)
  bool get hasActiveFilters =>
      hasSearch ||
          instrumentCodes.isNotEmpty ||
          partCodes.isNotEmpty ||
          woodCodes.isNotEmpty ||
          qualityCodes.isNotEmpty ||
          unit != null ||
          hasDateFilter ||
          features.isNotEmpty ||
          isActs != null ||
          years.isNotEmpty;

  /// Sind Shop-spezifische Nachfilter aktiv? (nur in der Shop-Ansicht relevant)
  bool get hasShopPropertyFilters =>
      features.isNotEmpty || isActs != null || years.isNotEmpty;

  /// Für Persistenz (`filter_settings`) und Favoriten.
  ///
  /// Datumswerte werden als millisecondsSinceEpoch (int) abgelegt, damit das
  /// Modell frei von Firestore-Typen (Timestamp) bleibt.
  Map<String, dynamic> toMap() => {
    'searchText': searchText,
    'instrumentCodes': instrumentCodes,
    'partCodes': partCodes,
    'woodCodes': woodCodes,
    'qualityCodes': qualityCodes,
    'unit': unit,
    'isOnlineShopView': isOnlineShopView,
    'shopFilter': shopFilter,
    'createdFrom': createdFrom?.millisecondsSinceEpoch,
    'createdTo': createdTo?.millisecondsSinceEpoch,
    'features': features.toList(),
    'isActs': isActs,
    'years': years,
  };

  factory WarehouseFilter.fromMap(Map<String, dynamic> map) => WarehouseFilter(
    searchText: (map['searchText'] ?? '') as String,
    instrumentCodes: List<String>.from(map['instrumentCodes'] ?? const []),
    partCodes: List<String>.from(map['partCodes'] ?? const []),
    woodCodes: List<String>.from(map['woodCodes'] ?? const []),
    qualityCodes: List<String>.from(map['qualityCodes'] ?? const []),
    unit: map['unit'] as String?,
    isOnlineShopView: (map['isOnlineShopView'] ?? false) as bool,
    shopFilter: map['shopFilter'] as String?,
    createdFrom: _dateFromMillis(map['createdFrom']),
    createdTo: _dateFromMillis(map['createdTo']),
    features: Set<String>.from(map['features'] ?? const []),
    isActs: map['isActs'] as bool?,
    years: List<String>.from(map['years'] ?? const []),
  );

  /// Liest einen millisecondsSinceEpoch-Wert (int) defensiv als DateTime.
  static DateTime? _dateFromMillis(Object? raw) {
    if (raw == null) return null;
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is num) return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    return null;
  }
}