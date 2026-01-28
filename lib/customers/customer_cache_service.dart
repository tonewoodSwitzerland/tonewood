import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'customer.dart';
class CustomerCacheService {
  static const String _cacheKey = 'cached_customers';
  static const String _lastRefreshKey = 'customers_last_refresh';
  static const int _refreshIntervalHours = 24;

  // Singleton Pattern
  static final CustomerCacheService _instance = CustomerCacheService._internal();
  factory CustomerCacheService() => _instance;
  CustomerCacheService._internal();

  // NEU: Listen von Callbacks statt einzelner Callbacks
  static final List<Function(Customer)> _onCustomerUpdatedListeners = [];
  static final List<Function(Customer)> _onCustomerAddedListeners = [];
  static final List<Function(String)> _onCustomerDeletedListeners = [];

  // NEU: Methoden zum Registrieren/Entfernen von Listenern
  static void addOnCustomerUpdatedListener(Function(Customer) listener) {
    _onCustomerUpdatedListeners.add(listener);
    print('📦 CustomerCache: Listener hinzugefügt (${_onCustomerUpdatedListeners.length} aktiv)');
  }

  static void removeOnCustomerUpdatedListener(Function(Customer) listener) {
    _onCustomerUpdatedListeners.remove(listener);
    print('📦 CustomerCache: Listener entfernt (${_onCustomerUpdatedListeners.length} aktiv)');
  }

  static void addOnCustomerAddedListener(Function(Customer) listener) {
    _onCustomerAddedListeners.add(listener);
  }

  static void removeOnCustomerAddedListener(Function(Customer) listener) {
    _onCustomerAddedListeners.remove(listener);
  }

  static void addOnCustomerDeletedListener(Function(String) listener) {
    _onCustomerDeletedListeners.add(listener);
  }

  static void removeOnCustomerDeletedListener(Function(String) listener) {
    _onCustomerDeletedListeners.remove(listener);
  }

  // In-Memory Cache
  List<Customer> _cachedCustomers = [];
  DateTime? _lastRefresh;
  bool _isInitialized = false;

  // Getter für gecachte Kunden
  List<Customer> get customers => _cachedCustomers;
  bool get isInitialized => _isInitialized;
  bool get isEmpty => _cachedCustomers.isEmpty;
  int get count => _cachedCustomers.length;

  /// Initialisiert den Cache beim App-Start
  Future<void> initialize() async {
    if (_isInitialized) return;

    print('📦 CustomerCache: Initialisiere...');

    // 1. Lade lokalen Cache (schnell!)
    await _loadFromLocalStorage();

    // 2. Prüfe ob Refresh nötig
    if (await _needsRefresh()) {
      print('📦 CustomerCache: Cache ist veraltet, lade neu...');
      await forceRefresh();
    } else {
      print('📦 CustomerCache: Cache ist aktuell (${_cachedCustomers.length} Kunden)');
    }

    _isInitialized = true;
  }

  /// Erzwingt einen Refresh des Caches
  Future<void> forceRefresh() async {
    print('📦 CustomerCache: Force Refresh gestartet...');

    try {
      // Alle Kunden von Firestore laden
      final snapshot = await FirebaseFirestore.instance
          .collection('customers')
          .get();

      _cachedCustomers = snapshot.docs
          .map((doc) => Customer.fromMap(doc.data(), doc.id))
          .toList();

      _lastRefresh = DateTime.now();

      // Lokal speichern
      await _saveToLocalStorage();

      // Timestamp in Firestore speichern
      await _saveRefreshTimestampToFirestore();

      print('📦 CustomerCache: ${_cachedCustomers.length} Kunden geladen und gecacht');
    } catch (e) {
      print('📦 CustomerCache: Fehler beim Refresh: $e');
      rethrow;
    }
  }

  /// Prüft ob ein Refresh nötig ist (> 24h seit letztem Refresh)
  Future<bool> _needsRefresh() async {
    if (_cachedCustomers.isEmpty) {
      print('📦 CustomerCache: Cache ist leer → Refresh nötig');
      return true;
    }

    if (_lastRefresh == null) {
      print('📦 CustomerCache: Kein Timestamp → Refresh nötig');
      return true;
    }

    final hoursSinceRefresh = DateTime.now().difference(_lastRefresh!).inHours;
    final needsRefresh = hoursSinceRefresh >= _refreshIntervalHours;

    print('📦 CustomerCache: Letzter Refresh vor $hoursSinceRefresh Stunden (Limit: $_refreshIntervalHours)');

    return needsRefresh;
  }

  /// Lädt Cache aus SharedPreferences
  Future<void> _loadFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Timestamp laden
      final timestampString = prefs.getString(_lastRefreshKey);
      if (timestampString != null) {
        _lastRefresh = DateTime.parse(timestampString);
      }

      // Kunden laden
      final jsonString = prefs.getString(_cacheKey);
      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString);
        _cachedCustomers = jsonList
            .map((json) => Customer.fromMap(json as Map<String, dynamic>, json['id'] ?? ''))
            .toList();

        print('📦 CustomerCache: ${_cachedCustomers.length} Kunden aus lokalem Cache geladen');
      }
    } catch (e) {
      print('📦 CustomerCache: Fehler beim Laden aus SharedPreferences: $e');
      _cachedCustomers = [];
      _lastRefresh = null;
    }
  }

  /// Speichert Cache in SharedPreferences
  Future<void> _saveToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Timestamp speichern
      if (_lastRefresh != null) {
        await prefs.setString(_lastRefreshKey, _lastRefresh!.toIso8601String());
      }

      // Kunden speichern
      final jsonList = _cachedCustomers.map((c) => c.toMap()).toList();
      await prefs.setString(_cacheKey, json.encode(jsonList));

      print('📦 CustomerCache: Cache lokal gespeichert');
    } catch (e) {
      print('📦 CustomerCache: Fehler beim Speichern in SharedPreferences: $e');
    }
  }

  /// Speichert Refresh-Timestamp in Firestore
  Future<void> _saveRefreshTimestampToFirestore() async {
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('app')
          .set({
        'lastCustomerRefresh': FieldValue.serverTimestamp(),
        'customerCount': _cachedCustomers.length,
      }, SetOptions(merge: true));

      print('📦 CustomerCache: Timestamp in Firestore gespeichert');
    } catch (e) {
      print('📦 CustomerCache: Fehler beim Speichern in Firestore: $e');
    }
  }

  // ============================================================================
  // CRUD-Operationen auf dem Cache
  // ============================================================================

  /// Aktualisiert einen Kunden im Cache
  void updateCustomer(Customer customer) {
    final index = _cachedCustomers.indexWhere((c) => c.id == customer.id);
    if (index != -1) {
      _cachedCustomers[index] = customer;
      _saveToLocalStorage();
      print('📦 CustomerCache: Kunde aktualisiert (${customer.id})');

      // NEU: Alle Listener benachrichtigen
      print('📦 CustomerCache: Benachrichtige ${_onCustomerUpdatedListeners.length} Listener');
      for (final listener in _onCustomerUpdatedListeners) {
        listener(customer);
      }
    } else {
      addCustomer(customer);
    }
  }

  /// Fügt einen neuen Kunden zum Cache hinzu
  void addCustomer(Customer customer) {
    _cachedCustomers.add(customer);
    _saveToLocalStorage();
    print('📦 CustomerCache: Kunde hinzugefügt (${customer.id})');

    // NEU: Alle Listener benachrichtigen
    for (final listener in _onCustomerAddedListeners) {
      listener(customer);
    }
  }

  /// Entfernt einen Kunden aus dem Cache
  void removeCustomer(String customerId) {
    _cachedCustomers.removeWhere((c) => c.id == customerId);
    _saveToLocalStorage();
    print('📦 CustomerCache: Kunde entfernt ($customerId)');

    // NEU: Alle Listener benachrichtigen
    for (final listener in _onCustomerDeletedListeners) {
      listener(customerId);
    }
  }

  /// Holt einen Kunden aus dem Cache
  Customer? getCustomer(String customerId) {
    try {
      return _cachedCustomers.firstWhere((c) => c.id == customerId);
    } catch (e) {
      return null;
    }
  }

  // ============================================================================
  // Such-Funktionen
  // ============================================================================

  /// Durchsucht den Cache nach einem Suchbegriff
  List<Customer> search(String searchTerm, {bool onlyFavorites = false}) {
    if (searchTerm.isEmpty && !onlyFavorites) {
      return _cachedCustomers;
    }

    final term = searchTerm.toLowerCase();

    return _cachedCustomers.where((customer) {
      // Favoriten-Filter
      if (onlyFavorites && !customer.isFavorite) {
        return false;
      }

      // Wenn kein Suchbegriff, nur Favoriten-Filter anwenden
      if (searchTerm.isEmpty) {
        return true;
      }

      // Suche in allen relevanten Feldern
      return customer.company.toLowerCase().contains(term) ||
          customer.firstName.toLowerCase().contains(term) ||
          customer.lastName.toLowerCase().contains(term) ||
          customer.name.toLowerCase().contains(term) ||
          customer.city.toLowerCase().contains(term) ||
          customer.email.toLowerCase().contains(term);
    }).toList();
  }

  /// Gibt nur Favoriten zurück
  List<Customer> get favorites {
    return _cachedCustomers.where((c) => c.isFavorite).toList();
  }

  /// Sortiert Kunden nach Firma/Name
  List<Customer> getSorted({bool onlyFavorites = false}) {
    final list = onlyFavorites ? favorites : _cachedCustomers;

    return List<Customer>.from(list)
      ..sort((a, b) {
        final aName = a.company.isNotEmpty ? a.company : a.name;
        final bName = b.company.isNotEmpty ? b.company : b.name;
        return aName.toLowerCase().compareTo(bName.toLowerCase());
      });
  }

  /// Cache leeren (z.B. beim Logout)
  Future<void> clear() async {
    _cachedCustomers = [];
    _lastRefresh = null;
    _isInitialized = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_lastRefreshKey);

    print('📦 CustomerCache: Cache geleert');
  }
}