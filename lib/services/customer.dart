class Customer {
  final String id;
  final String name;
  final String company;
  final String firstName;
  final String lastName;

  final String? addressSupplement; // Zusatz
  final String? districtPOBox; // Bezirk/Postfach etc

  final String street;
  final String houseNumber;
  final String zipCode;
  final String city;
  final String? province;
  final String country;
  final String? countryCode; // GEÄNDERT: Nullable machen
  final String email;

  // Neue Felder - alle nullable machen
  final String? phone1;
  final String? phone2;
  final String? vatNumber;
  final String? eoriNumber;
  final String language; // "DE" oder "EN" - bleibt required
  final bool wantsChristmasCard;
  final String? notes; // Nullable

  // Abweichende Lieferadresse - alle nullable machen
  final bool hasDifferentShippingAddress;
  final String? shippingCompany;
  final String? shippingFirstName;
  final String? shippingLastName;
  final String? shippingStreet;
  final String? shippingHouseNumber;
  final String? shippingZipCode;
  final String? shippingCity;
  final String? shippingProvince;
  final String? shippingCountry;
  final String? shippingCountryCode;
  final String? shippingPhone;
  final String? shippingEmail;
// NEU: Flags für Dokumentenanzeige
  final bool showVatOnDocuments;
  final bool showEoriOnDocuments;
  final bool showCustomFieldOnDocuments;  // NEU: Auch für custom Feld

  // NEU: Zusätzliche Felder für Lieferschein
  final String? customFieldTitle;
  final String? customFieldValue;

// NEU: Zusätzliche Adresszeilen
  final List<String> additionalAddressLines;
  final List<String> shippingAdditionalAddressLines;

  Customer({
    required this.id,
    required this.name,
    required this.company,
    required this.firstName,
    required this.lastName,
    this.addressSupplement,
    this.districtPOBox,
    required this.street,
    required this.houseNumber,
    required this.zipCode,
    required this.city,
    this.province, // NEU
    required this.country,
    this.countryCode, // GEÄNDERT: Kein Standardwert mehr
    required this.email,

    // Neue Felder - alle optional mit Standardwerten
    this.phone1,
    this.phone2,
    this.vatNumber,
    this.eoriNumber,
    this.language = 'DE', // Standardsprache Deutsch
    this.wantsChristmasCard = true, // Standardmäßig Weihnachtsbrief senden
    this.notes,

    // Abweichende Lieferadresse - alle optional
    this.hasDifferentShippingAddress = false,
    this.shippingCompany,
    this.shippingFirstName,
    this.shippingLastName,
    this.shippingStreet,
    this.shippingHouseNumber,
    this.shippingZipCode,
    this.shippingCity,
    this.shippingProvince, // NEU
    this.shippingCountry,
    this.shippingCountryCode,
    this.shippingPhone,
    this.shippingEmail,
    this.showCustomFieldOnDocuments = false,
    this.showVatOnDocuments = false,
    this.showEoriOnDocuments = false,
    this.customFieldTitle,
    this.customFieldValue,
    // NEU: Zusätzliche Adresszeilen
    this.additionalAddressLines = const [],
    this.shippingAdditionalAddressLines = const [],
  });

  factory Customer.fromMap(Map<String, dynamic> map, String id) {
    return Customer(
      id: id,
      name: map['name'] ?? '',
      company: map['company'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      street: map['street'] ?? '',
      houseNumber: map['houseNumber'] ?? '',
      zipCode: map['zipCode'] ?? '',
      city: map['city'] ?? '',
      province: map['province'], // NEU
      country: map['country'] ?? '',
      countryCode: map['countryCode'] ?? _getCountryCode(map['country'] ?? ''),
      email: map['email'] ?? '',
      addressSupplement: map['addressSupplement'],
      districtPOBox: map['districtPOBox'],

      // Neue Felder mit robusten Null-Checks
      phone1: map['phone1'],
      phone2: map['phone2'],
      vatNumber: map['vatNumber'],
      eoriNumber: map['eoriNumber'],
      language: map['language'] ?? 'DE',
      wantsChristmasCard: map['wantsChristmasCard'] ?? true,
      notes: map['notes'],

      // Abweichende Lieferadresse mit robusten Null-Checks
      hasDifferentShippingAddress: map['hasDifferentShippingAddress'] ?? false,
      shippingCompany: map['shippingCompany'],
      shippingFirstName: map['shippingFirstName'],
      shippingLastName: map['shippingLastName'],
      shippingStreet: map['shippingStreet'],
      shippingHouseNumber: map['shippingHouseNumber'],
      shippingZipCode: map['shippingZipCode'],
      shippingCity: map['shippingCity'],
      shippingProvince: map['shippingProvince'], // NEU
      shippingCountry: map['shippingCountry'],
      shippingCountryCode: map['shippingCountryCode'] ?? _getCountryCode(map['shippingCountry'] ?? ''),
      shippingPhone: map['shippingPhone'],
      shippingEmail: map['shippingEmail'],
      showCustomFieldOnDocuments: map['showCustomFieldOnDocuments'] ?? false,
      showVatOnDocuments: map['showVatOnDocuments'] ?? false,
      showEoriOnDocuments: map['showEoriOnDocuments'] ?? false,
      customFieldTitle: map['customFieldTitle'],
      customFieldValue: map['customFieldValue'],
      // NEU: Zusätzliche Adresszeilen
      additionalAddressLines: map['additionalAddressLines'] != null
          ? List<String>.from(map['additionalAddressLines'])
          : [],
      shippingAdditionalAddressLines: map['shippingAdditionalAddressLines'] != null
          ? List<String>.from(map['shippingAdditionalAddressLines'])
          : [],

    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'company': company,
      'firstName': firstName,
      'lastName': lastName,
      'street': street,
      'houseNumber': houseNumber,
      'zipCode': zipCode,
      'city': city,
      'province': province, // NEU
      'country': country,
      'countryCode': countryCode ?? _getCountryCode(country),
      'email': email,

      'addressSupplement': addressSupplement,
      'districtPOBox': districtPOBox,

      // Neue Felder
      'phone1': phone1,
      'phone2': phone2,
      'vatNumber': vatNumber,
      'eoriNumber': eoriNumber,
      'language': language,
      'wantsChristmasCard': wantsChristmasCard,
      'notes': notes,

      // Abweichende Lieferadresse
      'hasDifferentShippingAddress': hasDifferentShippingAddress,
      'shippingCompany': shippingCompany,
      'shippingFirstName': shippingFirstName,
      'shippingLastName': shippingLastName,
      'shippingStreet': shippingStreet,
      'shippingHouseNumber': shippingHouseNumber,
      'shippingZipCode': shippingZipCode,
      'shippingCity': shippingCity,
      'shippingProvince': shippingProvince,
      'shippingCountry': shippingCountry,
      'shippingCountryCode': shippingCountryCode ?? _getCountryCode(shippingCountry ?? ''),
      'shippingPhone': shippingPhone,
      'shippingEmail': shippingEmail,
      'showCustomFieldOnDocuments': showCustomFieldOnDocuments,
      'showVatOnDocuments': showVatOnDocuments,
      'showEoriOnDocuments': showEoriOnDocuments,
      'customFieldTitle': customFieldTitle,
      'customFieldValue': customFieldValue,

      // NEU: Zusätzliche Adresszeilen
      'additionalAddressLines': additionalAddressLines,
      'shippingAdditionalAddressLines': shippingAdditionalAddressLines,
    };
  }

  // Getter für vollständigen Namen
  String get fullName => '$firstName $lastName'.trim();

  String get fullAddress {
    final parts = [
      '$street $houseNumber'.trim(),
      ...additionalAddressLines.where((line) => line.isNotEmpty),
      '$zipCode $city'.trim(),
      if (province?.isNotEmpty == true) province!, // KORRIGIERT
      country,
    ].where((part) => part.isNotEmpty);

    return parts.join(', ');
  }
  String get fullShippingAddress {
    if (!hasDifferentShippingAddress) return fullAddress;

    final parts = [
      '${shippingStreet ?? ''} ${shippingHouseNumber ?? ''}'.trim(),
      ...shippingAdditionalAddressLines.where((line) => line.isNotEmpty),
      '${shippingZipCode ?? ''} ${shippingCity ?? ''}'.trim(),
      if (shippingProvince?.isNotEmpty == true) shippingProvince!, // KORRIGIERT
      shippingCountry ?? '',
    ].where((part) => part.isNotEmpty);

    return parts.join(', ');
  }
  // Getter für den Lieferempfänger
  String get shippingRecipientName {
    if (!hasDifferentShippingAddress) return fullName;

    final name = '${shippingFirstName ?? ''} ${shippingLastName ?? ''}'.trim();
    return name.isNotEmpty ? name : fullName;
  }

  // Hilfsmethode für das Länderkürzel
  static String _getCountryCode(String country) {
    if (country.isEmpty) return '';

    // Map von Ländernamen zu ISO-Codes
    final Map<String, String> countryCodes = {
      'Deutschland': 'DE',
      'Deutschland (Festland)': 'DE',
      'Germany': 'DE',
      'Schweiz': 'CH',
      'Switzerland': 'CH',
      'Österreich': 'AT',
      'Austria': 'AT',
      'Frankreich': 'FR',
      'France': 'FR',
      'Italien': 'IT',
      'Italy': 'IT',
      'Spanien': 'ES',
      'Spain': 'ES',
      'Vereinigtes Königreich': 'GB',
      'United Kingdom': 'GB',
      'UK': 'GB',
      'Großbritannien': 'GB',
      'Great Britain': 'GB',
      'England': 'GB',
      'Niederlande': 'NL',
      'Netherlands': 'NL',
      'Belgien': 'BE',
      'Belgium': 'BE',
      'Luxemburg': 'LU',
      'Luxembourg': 'LU',
      'Dänemark': 'DK',
      'Denmark': 'DK',
      'Schweden': 'SE',
      'Sweden': 'SE',
      'Norwegen': 'NO',
      'Norway': 'NO',
      'Finnland': 'FI',
      'Finland': 'FI',
      'Portugal': 'PT',
      'Griechenland': 'GR',
      'Greece': 'GR',
      'Irland': 'IE',
      'Ireland': 'IE',
      'USA': 'US',
      'Vereinigte Staaten': 'US',
      'United States': 'US',
      'Kanada': 'CA',
      'Canada': 'CA',
      'Japan': 'JP',
      // Weitere Länder können hier hinzugefügt werden
    };

    // Normalisiere Ländername für die Suche (Kleinbuchstaben)
    final normalizedCountry = country.trim().toLowerCase();

    // Versuche, den Code zu finden
    for (final entry in countryCodes.entries) {
      if (normalizedCountry == entry.key.toLowerCase()) {
        return entry.value;
      }
    }

    // Wenn kein Treffer gefunden wurde, gebe einen leeren String zurück
    return '';
  }

  // Erstelle eine Kopie dieser Customer-Instanz mit aktualisierten Werten
  Customer copyWith({
    String? id,
    String? name,
    String? company,
    String? firstName,
    String? lastName,
    String? addressSupplement,
    String? districtPOBox,
    String? street,
    String? houseNumber,
    String? zipCode,
    String? city,
    String? province, // NEU
    String? country,
    String? countryCode,
    String? email,
    String? phone1,
    String? phone2,
    String? vatNumber,
    String? eoriNumber,
    String? language,
    bool? wantsChristmasCard,
    String? notes,
    bool? hasDifferentShippingAddress,
    String? shippingCompany,
    String? shippingFirstName,
    String? shippingLastName,
    String? shippingStreet,
    String? shippingHouseNumber,
    String? shippingZipCode,
    String? shippingCity,
    String? shippingProvince, // NEU
    String? shippingCountry,
    String? shippingCountryCode,
    String? shippingPhone,
    String? shippingEmail,
    // NEU: Zusätzliche Adresszeilen
    List<String>? additionalAddressLines,
    List<String>? shippingAdditionalAddressLines,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      company: company ?? this.company,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      street: street ?? this.street,
      addressSupplement: addressSupplement ?? this.addressSupplement,
      districtPOBox: districtPOBox ?? this.districtPOBox,
      houseNumber: houseNumber ?? this.houseNumber,
      zipCode: zipCode ?? this.zipCode,
      city: city ?? this.city,
      province: province ?? this.province, // NEU
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      email: email ?? this.email,
      phone1: phone1 ?? this.phone1,
      phone2: phone2 ?? this.phone2,
      vatNumber: vatNumber ?? this.vatNumber,
      eoriNumber: eoriNumber ?? this.eoriNumber,
      language: language ?? this.language,
      wantsChristmasCard: wantsChristmasCard ?? this.wantsChristmasCard,
      notes: notes ?? this.notes,
      hasDifferentShippingAddress: hasDifferentShippingAddress ?? this.hasDifferentShippingAddress,
      shippingCompany: shippingCompany ?? this.shippingCompany,
      shippingFirstName: shippingFirstName ?? this.shippingFirstName,
      shippingLastName: shippingLastName ?? this.shippingLastName,
      shippingStreet: shippingStreet ?? this.shippingStreet,
      shippingHouseNumber: shippingHouseNumber ?? this.shippingHouseNumber,
      shippingZipCode: shippingZipCode ?? this.shippingZipCode,
      shippingCity: shippingCity ?? this.shippingCity,
      shippingProvince: shippingProvince ?? this.shippingProvince, // NEU
      shippingCountry: shippingCountry ?? this.shippingCountry,
      shippingCountryCode: shippingCountryCode ?? this.shippingCountryCode,
      shippingPhone: shippingPhone ?? this.shippingPhone,
      shippingEmail: shippingEmail ?? this.shippingEmail,
      additionalAddressLines: additionalAddressLines ?? this.additionalAddressLines,
      shippingAdditionalAddressLines: shippingAdditionalAddressLines ?? this.shippingAdditionalAddressLines,

    );
  }
}