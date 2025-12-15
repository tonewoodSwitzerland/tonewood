class Customer {
  final String id;
  final String name;
  final String company;
  final String firstName;
  final String lastName;

  final String? addressSupplement;
  final String? districtPOBox;

  final String street;
  final String houseNumber;
  final String zipCode;
  final String city;
  final String? province;
  final String country;
  final String? countryCode;
  final String email;

  final String? phone1;
  final String? phone2;
  final String? vatNumber;
  final String? eoriNumber;
  final String language;
  final bool wantsChristmasCard;
  final String? notes;

  // Abweichende Lieferadresse
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

  final bool showVatOnDocuments;
  final bool showEoriOnDocuments;
  final bool showCustomFieldOnDocuments;

  final String? customFieldTitle;
  final String? customFieldValue;

  final List<String> additionalAddressLines;
  final List<String> shippingAdditionalAddressLines;

  // NEU: Kundengruppen
  final List<String> customerGroupIds;

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
    this.province,
    required this.country,
    this.countryCode,
    required this.email,
    this.phone1,
    this.phone2,
    this.vatNumber,
    this.eoriNumber,
    this.language = 'DE',
    this.wantsChristmasCard = true,
    this.notes,
    this.hasDifferentShippingAddress = false,
    this.shippingCompany,
    this.shippingFirstName,
    this.shippingLastName,
    this.shippingStreet,
    this.shippingHouseNumber,
    this.shippingZipCode,
    this.shippingCity,
    this.shippingProvince,
    this.shippingCountry,
    this.shippingCountryCode,
    this.shippingPhone,
    this.shippingEmail,
    this.showCustomFieldOnDocuments = false,
    this.showVatOnDocuments = false,
    this.showEoriOnDocuments = false,
    this.customFieldTitle,
    this.customFieldValue,
    this.additionalAddressLines = const [],
    this.shippingAdditionalAddressLines = const [],
    // NEU: Kundengruppen
    this.customerGroupIds = const [],
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
      province: map['province'],
      country: map['country'] ?? '',
      countryCode: map['countryCode'] ?? _getCountryCode(map['country'] ?? ''),
      email: map['email'] ?? '',
      addressSupplement: map['addressSupplement'],
      districtPOBox: map['districtPOBox'],
      phone1: map['phone1'],
      phone2: map['phone2'],
      vatNumber: map['vatNumber'],
      eoriNumber: map['eoriNumber'],
      language: map['language'] ?? 'DE',
      wantsChristmasCard: map['wantsChristmasCard'] ?? true,
      notes: map['notes'],
      hasDifferentShippingAddress: map['hasDifferentShippingAddress'] ?? false,
      shippingCompany: map['shippingCompany'],
      shippingFirstName: map['shippingFirstName'],
      shippingLastName: map['shippingLastName'],
      shippingStreet: map['shippingStreet'],
      shippingHouseNumber: map['shippingHouseNumber'],
      shippingZipCode: map['shippingZipCode'],
      shippingCity: map['shippingCity'],
      shippingProvince: map['shippingProvince'],
      shippingCountry: map['shippingCountry'],
      shippingCountryCode: map['shippingCountryCode'] ?? _getCountryCode(map['shippingCountry'] ?? ''),
      shippingPhone: map['shippingPhone'],
      shippingEmail: map['shippingEmail'],
      showCustomFieldOnDocuments: map['showCustomFieldOnDocuments'] ?? false,
      showVatOnDocuments: map['showVatOnDocuments'] ?? false,
      showEoriOnDocuments: map['showEoriOnDocuments'] ?? false,
      customFieldTitle: map['customFieldTitle'],
      customFieldValue: map['customFieldValue'],
      additionalAddressLines: map['additionalAddressLines'] != null
          ? List<String>.from(map['additionalAddressLines'])
          : [],
      shippingAdditionalAddressLines: map['shippingAdditionalAddressLines'] != null
          ? List<String>.from(map['shippingAdditionalAddressLines'])
          : [],
      // NEU: Kundengruppen
      customerGroupIds: map['customerGroupIds'] != null
          ? List<String>.from(map['customerGroupIds'])
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
      'province': province,
      'country': country,
      'countryCode': countryCode ?? _getCountryCode(country),
      'email': email,
      'addressSupplement': addressSupplement,
      'districtPOBox': districtPOBox,
      'phone1': phone1,
      'phone2': phone2,
      'vatNumber': vatNumber,
      'eoriNumber': eoriNumber,
      'language': language,
      'wantsChristmasCard': wantsChristmasCard,
      'notes': notes,
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
      'additionalAddressLines': additionalAddressLines,
      'shippingAdditionalAddressLines': shippingAdditionalAddressLines,
      // NEU: Kundengruppen
      'customerGroupIds': customerGroupIds,
    };
  }

  String get fullName => '$firstName $lastName'.trim();

  String get fullAddress {
    final parts = [
      '$street $houseNumber'.trim(),
      ...additionalAddressLines.where((line) => line.isNotEmpty),
      '$zipCode $city'.trim(),
      if (province?.isNotEmpty == true) province!,
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
      if (shippingProvince?.isNotEmpty == true) shippingProvince!,
      shippingCountry ?? '',
    ].where((part) => part.isNotEmpty);
    return parts.join(', ');
  }

  String get shippingRecipientName {
    if (!hasDifferentShippingAddress) return fullName;
    final name = '${shippingFirstName ?? ''} ${shippingLastName ?? ''}'.trim();
    return name.isNotEmpty ? name : fullName;
  }

  // NEU: Hat Kundengruppen?
  bool get hasCustomerGroups => customerGroupIds.isNotEmpty;

  static String _getCountryCode(String country) {
    if (country.isEmpty) return '';
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
    };
    final normalizedCountry = country.trim().toLowerCase();
    for (final entry in countryCodes.entries) {
      if (normalizedCountry == entry.key.toLowerCase()) {
        return entry.value;
      }
    }
    return '';
  }

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
    String? province,
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
    String? shippingProvince,
    String? shippingCountry,
    String? shippingCountryCode,
    String? shippingPhone,
    String? shippingEmail,
    List<String>? additionalAddressLines,
    List<String>? shippingAdditionalAddressLines,
    // NEU: Kundengruppen
    List<String>? customerGroupIds,
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
      province: province ?? this.province,
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
      shippingProvince: shippingProvince ?? this.shippingProvince,
      shippingCountry: shippingCountry ?? this.shippingCountry,
      shippingCountryCode: shippingCountryCode ?? this.shippingCountryCode,
      shippingPhone: shippingPhone ?? this.shippingPhone,
      shippingEmail: shippingEmail ?? this.shippingEmail,
      additionalAddressLines: additionalAddressLines ?? this.additionalAddressLines,
      shippingAdditionalAddressLines: shippingAdditionalAddressLines ?? this.shippingAdditionalAddressLines,
      // NEU: Kundengruppen
      customerGroupIds: customerGroupIds ?? this.customerGroupIds,
    );
  }
}