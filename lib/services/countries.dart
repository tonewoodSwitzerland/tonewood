/// Definiert eine Klasse zur Repräsentation eines Landes mit Namen und ISO-Code
class Country {
  final String name;
  final String nameEn;
  final String code;

  const Country({required this.name, required this.nameEn, required this.code});

  // Gibt den Namen in der gewünschten Sprache zurück
  String getNameForLanguage(String language) {
    return language == 'EN' ? nameEn : name;
  }

  @override
  String toString() => name;
}

/// Liste aller Länder mit ihren offiziellen ISO-Codes (ISO 3166-1 alpha-2)
class Countries {
  // Singleton-Pattern
  static final Countries _instance = Countries._internal();
  factory Countries() => _instance;
  Countries._internal();

  // Liste aller Länder
  static final List<Country> allCountries = [
    const Country(name: "Afghanistan", nameEn: "Afghanistan", code: "AF"),
    const Country(name: "Ägypten", nameEn: "Egypt", code: "EG"),
    const Country(name: "Albanien", nameEn: "Albania", code: "AL"),
    const Country(name: "Algerien", nameEn: "Algeria", code: "DZ"),
    const Country(name: "Andorra", nameEn: "Andorra", code: "AD"),
    const Country(name: "Angola", nameEn: "Angola", code: "AO"),
    const Country(name: "Antigua und Barbuda", nameEn: "Antigua and Barbuda", code: "AG"),
    const Country(name: "Äquatorialguinea", nameEn: "Equatorial Guinea", code: "GQ"),
    const Country(name: "Argentinien", nameEn: "Argentina", code: "AR"),
    const Country(name: "Armenien", nameEn: "Armenia", code: "AM"),
    const Country(name: "Aserbaidschan", nameEn: "Azerbaijan", code: "AZ"),
    const Country(name: "Äthiopien", nameEn: "Ethiopia", code: "ET"),
    const Country(name: "Australien", nameEn: "Australia", code: "AU"),
    const Country(name: "Bahamas", nameEn: "Bahamas", code: "BS"),
    const Country(name: "Bahrain", nameEn: "Bahrain", code: "BH"),
    const Country(name: "Bangladesch", nameEn: "Bangladesh", code: "BD"),
    const Country(name: "Barbados", nameEn: "Barbados", code: "BB"),
    const Country(name: "Belarus", nameEn: "Belarus", code: "BY"),
    const Country(name: "Belgien", nameEn: "Belgium", code: "BE"),
    const Country(name: "Belize", nameEn: "Belize", code: "BZ"),
    const Country(name: "Benin", nameEn: "Benin", code: "BJ"),
    const Country(name: "Bhutan", nameEn: "Bhutan", code: "BT"),
    const Country(name: "Bolivien", nameEn: "Bolivia", code: "BO"),
    const Country(name: "Bosnien und Herzegowina", nameEn: "Bosnia and Herzegovina", code: "BA"),
    const Country(name: "Botswana", nameEn: "Botswana", code: "BW"),
    const Country(name: "Brasilien", nameEn: "Brazil", code: "BR"),
    const Country(name: "Brunei Darussalam", nameEn: "Brunei Darussalam", code: "BN"),
    const Country(name: "Bulgarien", nameEn: "Bulgaria", code: "BG"),
    const Country(name: "Burkina Faso", nameEn: "Burkina Faso", code: "BF"),
    const Country(name: "Burundi", nameEn: "Burundi", code: "BI"),
    const Country(name: "Cabo Verde", nameEn: "Cabo Verde", code: "CV"),
    const Country(name: "Chile", nameEn: "Chile", code: "CL"),
    const Country(name: "China", nameEn: "China", code: "CN"),
    const Country(name: "Cookinseln", nameEn: "Cook Islands", code: "CK"),
    const Country(name: "Costa Rica", nameEn: "Costa Rica", code: "CR"),
    const Country(name: "Côte d'Ivoire", nameEn: "Côte d'Ivoire", code: "CI"),
    const Country(name: "Dänemark", nameEn: "Denmark", code: "DK"),
    const Country(name: "Deutschland", nameEn: "Germany", code: "DE"),
    const Country(name: "Dominica", nameEn: "Dominica", code: "DM"),
    const Country(name: "Dominikanische Republik", nameEn: "Dominican Republic", code: "DO"),
    const Country(name: "Dschibuti", nameEn: "Djibouti", code: "DJ"),
    const Country(name: "Ecuador", nameEn: "Ecuador", code: "EC"),
    const Country(name: "El Salvador", nameEn: "El Salvador", code: "SV"),
    const Country(name: "Eritrea", nameEn: "Eritrea", code: "ER"),
    const Country(name: "Estland", nameEn: "Estonia", code: "EE"),
    const Country(name: "Eswatini", nameEn: "Eswatini", code: "SZ"),
    const Country(name: "Fidschi", nameEn: "Fiji", code: "FJ"),
    const Country(name: "Finnland", nameEn: "Finland", code: "FI"),
    const Country(name: "Frankreich", nameEn: "France", code: "FR"),
    const Country(name: "Gabun", nameEn: "Gabon", code: "GA"),
    const Country(name: "Gambia", nameEn: "Gambia", code: "GM"),
    const Country(name: "Georgien", nameEn: "Georgia", code: "GE"),
    const Country(name: "Ghana", nameEn: "Ghana", code: "GH"),
    const Country(name: "Grenada", nameEn: "Grenada", code: "GD"),
    const Country(name: "Griechenland", nameEn: "Greece", code: "GR"),
    const Country(name: "Guatemala", nameEn: "Guatemala", code: "GT"),
    const Country(name: "Guinea", nameEn: "Guinea", code: "GN"),
    const Country(name: "Guinea-Bissau", nameEn: "Guinea-Bissau", code: "GW"),
    const Country(name: "Guyana", nameEn: "Guyana", code: "GY"),
    const Country(name: "Haiti", nameEn: "Haiti", code: "HT"),
    const Country(name: "Honduras", nameEn: "Honduras", code: "HN"),
    const Country(name: "Indien", nameEn: "India", code: "IN"),
    const Country(name: "Indonesien", nameEn: "Indonesia", code: "ID"),
    const Country(name: "Irak", nameEn: "Iraq", code: "IQ"),
    const Country(name: "Iran", nameEn: "Iran", code: "IR"),
    const Country(name: "Irland", nameEn: "Ireland", code: "IE"),
    const Country(name: "Island", nameEn: "Iceland", code: "IS"),
    const Country(name: "Israel", nameEn: "Israel", code: "IL"),
    const Country(name: "Italien", nameEn: "Italy", code: "IT"),
    const Country(name: "Jamaika", nameEn: "Jamaica", code: "JM"),
    const Country(name: "Japan", nameEn: "Japan", code: "JP"),
    const Country(name: "Jemen", nameEn: "Yemen", code: "YE"),
    const Country(name: "Jordanien", nameEn: "Jordan", code: "JO"),
    const Country(name: "Kambodscha", nameEn: "Cambodia", code: "KH"),
    const Country(name: "Kamerun", nameEn: "Cameroon", code: "CM"),
    const Country(name: "Kanada", nameEn: "Canada", code: "CA"),
    const Country(name: "Kasachstan", nameEn: "Kazakhstan", code: "KZ"),
    const Country(name: "Katar", nameEn: "Qatar", code: "QA"),
    const Country(name: "Kenia", nameEn: "Kenya", code: "KE"),
    const Country(name: "Kirgisistan", nameEn: "Kyrgyzstan", code: "KG"),
    const Country(name: "Kiribati", nameEn: "Kiribati", code: "KI"),
    const Country(name: "Kolumbien", nameEn: "Colombia", code: "CO"),
    const Country(name: "Komoren", nameEn: "Comoros", code: "KM"),
    const Country(name: "Kongo", nameEn: "Congo", code: "CG"),
    const Country(name: "Demokratische Republik Kongo", nameEn: "Democratic Republic of the Congo", code: "CD"),
    const Country(name: "Korea, Demokratische Volksrepublik", nameEn: "North Korea", code: "KP"),
    const Country(name: "Korea, Republik", nameEn: "South Korea", code: "KR"),
    const Country(name: "Kosovo", nameEn: "Kosovo", code: "XK"),
    const Country(name: "Kroatien", nameEn: "Croatia", code: "HR"),
    const Country(name: "Kuba", nameEn: "Cuba", code: "CU"),
    const Country(name: "Kuwait", nameEn: "Kuwait", code: "KW"),
    const Country(name: "Laos", nameEn: "Laos", code: "LA"),
    const Country(name: "Lesotho", nameEn: "Lesotho", code: "LS"),
    const Country(name: "Lettland", nameEn: "Latvia", code: "LV"),
    const Country(name: "Libanon", nameEn: "Lebanon", code: "LB"),
    const Country(name: "Liberia", nameEn: "Liberia", code: "LR"),
    const Country(name: "Libyen", nameEn: "Libya", code: "LY"),
    const Country(name: "Liechtenstein", nameEn: "Liechtenstein", code: "LI"),
    const Country(name: "Litauen", nameEn: "Lithuania", code: "LT"),
    const Country(name: "Luxemburg", nameEn: "Luxembourg", code: "LU"),
    const Country(name: "Madagaskar", nameEn: "Madagascar", code: "MG"),
    const Country(name: "Malawi", nameEn: "Malawi", code: "MW"),
    const Country(name: "Malaysia", nameEn: "Malaysia", code: "MY"),
    const Country(name: "Malediven", nameEn: "Maldives", code: "MV"),
    const Country(name: "Mali", nameEn: "Mali", code: "ML"),
    const Country(name: "Malta", nameEn: "Malta", code: "MT"),
    const Country(name: "Marokko", nameEn: "Morocco", code: "MA"),
    const Country(name: "Marshallinseln", nameEn: "Marshall Islands", code: "MH"),
    const Country(name: "Mauretanien", nameEn: "Mauritania", code: "MR"),
    const Country(name: "Mauritius", nameEn: "Mauritius", code: "MU"),
    const Country(name: "Mexiko", nameEn: "Mexico", code: "MX"),
    const Country(name: "Mikronesien", nameEn: "Micronesia", code: "FM"),
    const Country(name: "Moldau", nameEn: "Moldova", code: "MD"),
    const Country(name: "Monaco", nameEn: "Monaco", code: "MC"),
    const Country(name: "Mongolei", nameEn: "Mongolia", code: "MN"),
    const Country(name: "Montenegro", nameEn: "Montenegro", code: "ME"),
    const Country(name: "Mosambik", nameEn: "Mozambique", code: "MZ"),
    const Country(name: "Myanmar", nameEn: "Myanmar", code: "MM"),
    const Country(name: "Namibia", nameEn: "Namibia", code: "NA"),
    const Country(name: "Nauru", nameEn: "Nauru", code: "NR"),
    const Country(name: "Nepal", nameEn: "Nepal", code: "NP"),
    const Country(name: "Neuseeland", nameEn: "New Zealand", code: "NZ"),
    const Country(name: "Nicaragua", nameEn: "Nicaragua", code: "NI"),
    const Country(name: "Niederlande", nameEn: "Netherlands", code: "NL"),
    const Country(name: "Niger", nameEn: "Niger", code: "NE"),
    const Country(name: "Nigeria", nameEn: "Nigeria", code: "NG"),
    const Country(name: "Nordmazedonien", nameEn: "North Macedonia", code: "MK"),
    const Country(name: "Norwegen", nameEn: "Norway", code: "NO"),
    const Country(name: "Oman", nameEn: "Oman", code: "OM"),
    const Country(name: "Österreich", nameEn: "Austria", code: "AT"),
    const Country(name: "Pakistan", nameEn: "Pakistan", code: "PK"),
    const Country(name: "Palau", nameEn: "Palau", code: "PW"),
    const Country(name: "Panama", nameEn: "Panama", code: "PA"),
    const Country(name: "Papua-Neuguinea", nameEn: "Papua New Guinea", code: "PG"),
    const Country(name: "Paraguay", nameEn: "Paraguay", code: "PY"),
    const Country(name: "Peru", nameEn: "Peru", code: "PE"),
    const Country(name: "Philippinen", nameEn: "Philippines", code: "PH"),
    const Country(name: "Polen", nameEn: "Poland", code: "PL"),
    const Country(name: "Portugal", nameEn: "Portugal", code: "PT"),
    const Country(name: "Ruanda", nameEn: "Rwanda", code: "RW"),
    const Country(name: "Rumänien", nameEn: "Romania", code: "RO"),
    const Country(name: "Russland", nameEn: "Russia", code: "RU"),
    const Country(name: "Salomonen", nameEn: "Solomon Islands", code: "SB"),
    const Country(name: "Sambia", nameEn: "Zambia", code: "ZM"),
    const Country(name: "Samoa", nameEn: "Samoa", code: "WS"),
    const Country(name: "San Marino", nameEn: "San Marino", code: "SM"),
    const Country(name: "São Tomé und Príncipe", nameEn: "São Tomé and Príncipe", code: "ST"),
    const Country(name: "Saudi-Arabien", nameEn: "Saudi Arabia", code: "SA"),
    const Country(name: "Schweden", nameEn: "Sweden", code: "SE"),
    const Country(name: "Schweiz", nameEn: "Switzerland", code: "CH"),
    const Country(name: "Senegal", nameEn: "Senegal", code: "SN"),
    const Country(name: "Serbien", nameEn: "Serbia", code: "RS"),
    const Country(name: "Seychellen", nameEn: "Seychelles", code: "SC"),
    const Country(name: "Sierra Leone", nameEn: "Sierra Leone", code: "SL"),
    const Country(name: "Simbabwe", nameEn: "Zimbabwe", code: "ZW"),
    const Country(name: "Singapur", nameEn: "Singapore", code: "SG"),
    const Country(name: "Slowakei", nameEn: "Slovakia", code: "SK"),
    const Country(name: "Slowenien", nameEn: "Slovenia", code: "SI"),
    const Country(name: "Somalia", nameEn: "Somalia", code: "SO"),
    const Country(name: "Spanien", nameEn: "Spain", code: "ES"),
    const Country(name: "Sri Lanka", nameEn: "Sri Lanka", code: "LK"),
    const Country(name: "St. Kitts und Nevis", nameEn: "St. Kitts and Nevis", code: "KN"),
    const Country(name: "St. Lucia", nameEn: "St. Lucia", code: "LC"),
    const Country(name: "St. Vincent und die Grenadinen", nameEn: "St. Vincent and the Grenadines", code: "VC"),
    const Country(name: "Südafrika", nameEn: "South Africa", code: "ZA"),
    const Country(name: "Sudan", nameEn: "Sudan", code: "SD"),
    const Country(name: "Südsudan", nameEn: "South Sudan", code: "SS"),
    const Country(name: "Suriname", nameEn: "Suriname", code: "SR"),
    const Country(name: "Syrien", nameEn: "Syria", code: "SY"),
    const Country(name: "Tadschikistan", nameEn: "Tajikistan", code: "TJ"),
    const Country(name: "Taiwan", nameEn: "Taiwan", code: "TW"),
    const Country(name: "Tansania", nameEn: "Tanzania", code: "TZ"),
    const Country(name: "Thailand", nameEn: "Thailand", code: "TH"),
    const Country(name: "Timor-Leste", nameEn: "Timor-Leste", code: "TL"),
    const Country(name: "Togo", nameEn: "Togo", code: "TG"),
    const Country(name: "Tonga", nameEn: "Tonga", code: "TO"),
    const Country(name: "Trinidad und Tobago", nameEn: "Trinidad and Tobago", code: "TT"),
    const Country(name: "Tschad", nameEn: "Chad", code: "TD"),
    const Country(name: "Tschechien", nameEn: "Czech Republic", code: "CZ"),
    const Country(name: "Tunesien", nameEn: "Tunisia", code: "TN"),
    const Country(name: "Türkei", nameEn: "Turkey", code: "TR"),
    const Country(name: "Turkmenistan", nameEn: "Turkmenistan", code: "TM"),
    const Country(name: "Tuvalu", nameEn: "Tuvalu", code: "TV"),
    const Country(name: "Uganda", nameEn: "Uganda", code: "UG"),
    const Country(name: "Ukraine", nameEn: "Ukraine", code: "UA"),
    const Country(name: "Ungarn", nameEn: "Hungary", code: "HU"),
    const Country(name: "Uruguay", nameEn: "Uruguay", code: "UY"),
    const Country(name: "Usbekistan", nameEn: "Uzbekistan", code: "UZ"),
    const Country(name: "Vanuatu", nameEn: "Vanuatu", code: "VU"),
    const Country(name: "Vatikanstadt", nameEn: "Vatican City", code: "VA"),
    const Country(name: "Venezuela", nameEn: "Venezuela", code: "VE"),
    const Country(name: "Vereinigte Arabische Emirate", nameEn: "United Arab Emirates", code: "AE"),
    const Country(name: "Vereinigtes Königreich", nameEn: "United Kingdom", code: "GB"),
    const Country(name: "Vereinigte Staaten", nameEn: "United States", code: "US"),
    const Country(name: "Vietnam", nameEn: "Vietnam", code: "VN"),
    const Country(name: "Weißrussland", nameEn: "Belarus", code: "BY"),
    const Country(name: "Zentralafrikanische Republik", nameEn: "Central African Republic", code: "CF"),
    const Country(name: "Zypern", nameEn: "Cyprus", code: "CY"),
  ];

  // Liste der beliebtesten oder häufig verwendeten Länder (für Schnellauswahl)
  static final List<Country> popularCountries = [
    getCountryByCode("CH"), // Schweiz
    getCountryByCode("DE"), // Deutschland
    getCountryByCode("AT"), // Österreich
    getCountryByCode("FR"), // Frankreich
    getCountryByCode("IT"), // Italien
    getCountryByCode("GB"), // Vereinigtes Königreich
    getCountryByCode("ES"), // Spanien
    getCountryByCode("US"), // Vereinigte Staaten
  ];

  // Land nach Code finden
  static Country getCountryByCode(String code) {
    return allCountries.firstWhere(
          (country) => country.code == code,
      orElse: () => const Country(name: "Unbekannt", nameEn: "Unknown", code: ""),
    );
  }

  // Land nach Name finden (Teilstring-Suche)
  static List<Country> searchCountriesByName(String query) {
    if (query.isEmpty) return allCountries;

    final normalizedQuery = query.toLowerCase().trim();
    return allCountries.where((country) =>
    country.name.toLowerCase().contains(normalizedQuery) ||
        country.nameEn.toLowerCase().contains(normalizedQuery) ||
        country.code.toLowerCase().contains(normalizedQuery)
    ).toList();
  }

  // Land nach Name finden (exakte Übereinstimmung)
  static Country? getCountryByName(String name) {
    try {
      return allCountries.firstWhere(
            (country) =>
        country.name.toLowerCase() == name.toLowerCase().trim() ||
            country.nameEn.toLowerCase() == name.toLowerCase().trim(),
      );
    } catch (e) {
      return null;
    }
  }

  // Ländercode für einen Namen abrufen
  static String getCodeForName(String name) {
    final country = getCountryByName(name);
    return country?.code ?? "";
  }
}