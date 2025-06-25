/// Definiert eine Klasse zur Repräsentation eines Landes mit Namen und ISO-Code
class Country {
  final String name;
  final String code;

  const Country({required this.name, required this.code});

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
    const Country(name: "Afghanistan", code: "AF"),
    const Country(name: "Ägypten", code: "EG"),
    const Country(name: "Albanien", code: "AL"),
    const Country(name: "Algerien", code: "DZ"),
    const Country(name: "Andorra", code: "AD"),
    const Country(name: "Angola", code: "AO"),
    const Country(name: "Antigua und Barbuda", code: "AG"),
    const Country(name: "Äquatorialguinea", code: "GQ"),
    const Country(name: "Argentinien", code: "AR"),
    const Country(name: "Armenien", code: "AM"),
    const Country(name: "Aserbaidschan", code: "AZ"),
    const Country(name: "Äthiopien", code: "ET"),
    const Country(name: "Australien", code: "AU"),
    const Country(name: "Bahamas", code: "BS"),
    const Country(name: "Bahrain", code: "BH"),
    const Country(name: "Bangladesch", code: "BD"),
    const Country(name: "Barbados", code: "BB"),
    const Country(name: "Belarus", code: "BY"),
    const Country(name: "Belgien", code: "BE"),
    const Country(name: "Belize", code: "BZ"),
    const Country(name: "Benin", code: "BJ"),
    const Country(name: "Bhutan", code: "BT"),
    const Country(name: "Bolivien", code: "BO"),
    const Country(name: "Bosnien und Herzegowina", code: "BA"),
    const Country(name: "Botswana", code: "BW"),
    const Country(name: "Brasilien", code: "BR"),
    const Country(name: "Brunei Darussalam", code: "BN"),
    const Country(name: "Bulgarien", code: "BG"),
    const Country(name: "Burkina Faso", code: "BF"),
    const Country(name: "Burundi", code: "BI"),
    const Country(name: "Cabo Verde", code: "CV"),
    const Country(name: "Chile", code: "CL"),
    const Country(name: "China", code: "CN"),
    const Country(name: "Cookinseln", code: "CK"),
    const Country(name: "Costa Rica", code: "CR"),
    const Country(name: "Côte d'Ivoire", code: "CI"),
    const Country(name: "Dänemark", code: "DK"),
    const Country(name: "Deutschland", code: "DE"),
    const Country(name: "Dominica", code: "DM"),
    const Country(name: "Dominikanische Republik", code: "DO"),
    const Country(name: "Dschibuti", code: "DJ"),
    const Country(name: "Ecuador", code: "EC"),
    const Country(name: "El Salvador", code: "SV"),
    const Country(name: "Eritrea", code: "ER"),
    const Country(name: "Estland", code: "EE"),
    const Country(name: "Eswatini", code: "SZ"),
    const Country(name: "Fidschi", code: "FJ"),
    const Country(name: "Finnland", code: "FI"),
    const Country(name: "Frankreich", code: "FR"),
    const Country(name: "Gabun", code: "GA"),
    const Country(name: "Gambia", code: "GM"),
    const Country(name: "Georgien", code: "GE"),
    const Country(name: "Ghana", code: "GH"),
    const Country(name: "Grenada", code: "GD"),
    const Country(name: "Griechenland", code: "GR"),
    const Country(name: "Guatemala", code: "GT"),
    const Country(name: "Guinea", code: "GN"),
    const Country(name: "Guinea-Bissau", code: "GW"),
    const Country(name: "Guyana", code: "GY"),
    const Country(name: "Haiti", code: "HT"),
    const Country(name: "Honduras", code: "HN"),
    const Country(name: "Indien", code: "IN"),
    const Country(name: "Indonesien", code: "ID"),
    const Country(name: "Irak", code: "IQ"),
    const Country(name: "Iran", code: "IR"),
    const Country(name: "Irland", code: "IE"),
    const Country(name: "Island", code: "IS"),
    const Country(name: "Israel", code: "IL"),
    const Country(name: "Italien", code: "IT"),
    const Country(name: "Jamaika", code: "JM"),
    const Country(name: "Japan", code: "JP"),
    const Country(name: "Jemen", code: "YE"),
    const Country(name: "Jordanien", code: "JO"),
    const Country(name: "Kambodscha", code: "KH"),
    const Country(name: "Kamerun", code: "CM"),
    const Country(name: "Kanada", code: "CA"),
    const Country(name: "Kasachstan", code: "KZ"),
    const Country(name: "Katar", code: "QA"),
    const Country(name: "Kenia", code: "KE"),
    const Country(name: "Kirgisistan", code: "KG"),
    const Country(name: "Kiribati", code: "KI"),
    const Country(name: "Kolumbien", code: "CO"),
    const Country(name: "Komoren", code: "KM"),
    const Country(name: "Kongo", code: "CG"),
    const Country(name: "Demokratische Republik Kongo", code: "CD"),
    const Country(name: "Korea, Demokratische Volksrepublik", code: "KP"),
    const Country(name: "Korea, Republik", code: "KR"),
    const Country(name: "Kosovo", code: "XK"),
    const Country(name: "Kroatien", code: "HR"),
    const Country(name: "Kuba", code: "CU"),
    const Country(name: "Kuwait", code: "KW"),
    const Country(name: "Laos", code: "LA"),
    const Country(name: "Lesotho", code: "LS"),
    const Country(name: "Lettland", code: "LV"),
    const Country(name: "Libanon", code: "LB"),
    const Country(name: "Liberia", code: "LR"),
    const Country(name: "Libyen", code: "LY"),
    const Country(name: "Liechtenstein", code: "LI"),
    const Country(name: "Litauen", code: "LT"),
    const Country(name: "Luxemburg", code: "LU"),
    const Country(name: "Madagaskar", code: "MG"),
    const Country(name: "Malawi", code: "MW"),
    const Country(name: "Malaysia", code: "MY"),
    const Country(name: "Malediven", code: "MV"),
    const Country(name: "Mali", code: "ML"),
    const Country(name: "Malta", code: "MT"),
    const Country(name: "Marokko", code: "MA"),
    const Country(name: "Marshallinseln", code: "MH"),
    const Country(name: "Mauretanien", code: "MR"),
    const Country(name: "Mauritius", code: "MU"),
    const Country(name: "Mexiko", code: "MX"),
    const Country(name: "Mikronesien", code: "FM"),
    const Country(name: "Moldau", code: "MD"),
    const Country(name: "Monaco", code: "MC"),
    const Country(name: "Mongolei", code: "MN"),
    const Country(name: "Montenegro", code: "ME"),
    const Country(name: "Mosambik", code: "MZ"),
    const Country(name: "Myanmar", code: "MM"),
    const Country(name: "Namibia", code: "NA"),
    const Country(name: "Nauru", code: "NR"),
    const Country(name: "Nepal", code: "NP"),
    const Country(name: "Neuseeland", code: "NZ"),
    const Country(name: "Nicaragua", code: "NI"),
    const Country(name: "Niederlande", code: "NL"),
    const Country(name: "Niger", code: "NE"),
    const Country(name: "Nigeria", code: "NG"),
    const Country(name: "Nordmazedonien", code: "MK"),
    const Country(name: "Norwegen", code: "NO"),
    const Country(name: "Oman", code: "OM"),
    const Country(name: "Österreich", code: "AT"),
    const Country(name: "Pakistan", code: "PK"),
    const Country(name: "Palau", code: "PW"),
    const Country(name: "Panama", code: "PA"),
    const Country(name: "Papua-Neuguinea", code: "PG"),
    const Country(name: "Paraguay", code: "PY"),
    const Country(name: "Peru", code: "PE"),
    const Country(name: "Philippinen", code: "PH"),
    const Country(name: "Polen", code: "PL"),
    const Country(name: "Portugal", code: "PT"),
    const Country(name: "Ruanda", code: "RW"),
    const Country(name: "Rumänien", code: "RO"),
    const Country(name: "Russland", code: "RU"),
    const Country(name: "Salomonen", code: "SB"),
    const Country(name: "Sambia", code: "ZM"),
    const Country(name: "Samoa", code: "WS"),
    const Country(name: "San Marino", code: "SM"),
    const Country(name: "São Tomé und Príncipe", code: "ST"),
    const Country(name: "Saudi-Arabien", code: "SA"),
    const Country(name: "Schweden", code: "SE"),
    const Country(name: "Schweiz", code: "CH"),
    const Country(name: "Senegal", code: "SN"),
    const Country(name: "Serbien", code: "RS"),
    const Country(name: "Seychellen", code: "SC"),
    const Country(name: "Sierra Leone", code: "SL"),
    const Country(name: "Simbabwe", code: "ZW"),
    const Country(name: "Singapur", code: "SG"),
    const Country(name: "Slowakei", code: "SK"),
    const Country(name: "Slowenien", code: "SI"),
    const Country(name: "Somalia", code: "SO"),
    const Country(name: "Spanien", code: "ES"),
    const Country(name: "Sri Lanka", code: "LK"),
    const Country(name: "St. Kitts und Nevis", code: "KN"),
    const Country(name: "St. Lucia", code: "LC"),
    const Country(name: "St. Vincent und die Grenadinen", code: "VC"),
    const Country(name: "Südafrika", code: "ZA"),
    const Country(name: "Sudan", code: "SD"),
    const Country(name: "Südsudan", code: "SS"),
    const Country(name: "Suriname", code: "SR"),
    const Country(name: "Syrien", code: "SY"),
    const Country(name: "Tadschikistan", code: "TJ"),
    const Country(name: "Taiwan", code: "TW"),
    const Country(name: "Tansania", code: "TZ"),
    const Country(name: "Thailand", code: "TH"),
    const Country(name: "Timor-Leste", code: "TL"),
    const Country(name: "Togo", code: "TG"),
    const Country(name: "Tonga", code: "TO"),
    const Country(name: "Trinidad und Tobago", code: "TT"),
    const Country(name: "Tschad", code: "TD"),
    const Country(name: "Tschechien", code: "CZ"),
    const Country(name: "Tunesien", code: "TN"),
    const Country(name: "Türkei", code: "TR"),
    const Country(name: "Turkmenistan", code: "TM"),
    const Country(name: "Tuvalu", code: "TV"),
    const Country(name: "Uganda", code: "UG"),
    const Country(name: "Ukraine", code: "UA"),
    const Country(name: "Ungarn", code: "HU"),
    const Country(name: "Uruguay", code: "UY"),
    const Country(name: "Usbekistan", code: "UZ"),
    const Country(name: "Vanuatu", code: "VU"),
    const Country(name: "Vatikanstadt", code: "VA"),
    const Country(name: "Venezuela", code: "VE"),
    const Country(name: "Vereinigte Arabische Emirate", code: "AE"),
    const Country(name: "Vereinigtes Königreich", code: "GB"),
    const Country(name: "Vereinigte Staaten", code: "US"),
    const Country(name: "Vietnam", code: "VN"),
    const Country(name: "Weißrussland", code: "BY"),
    const Country(name: "Zentralafrikanische Republik", code: "CF"),
    const Country(name: "Zypern", code: "CY"),
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
      orElse: () => const Country(name: "Unbekannt", code: ""),
    );
  }

  // Land nach Name finden (Teilstring-Suche)
  static List<Country> searchCountriesByName(String query) {
    if (query.isEmpty) return allCountries;

    final normalizedQuery = query.toLowerCase().trim();
    return allCountries.where((country) =>
    country.name.toLowerCase().contains(normalizedQuery) ||
        country.code.toLowerCase().contains(normalizedQuery)
    ).toList();
  }

  // Land nach Name finden (exakte Übereinstimmung)
  static Country? getCountryByName(String name) {
    try {
      return allCountries.firstWhere(
            (country) => country.name.toLowerCase() == name.toLowerCase().trim(),
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