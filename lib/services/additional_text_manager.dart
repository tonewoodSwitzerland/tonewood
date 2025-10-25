import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/icon_helper.dart';

class AdditionalTextsManager {
  static const String COLLECTION_NAME = 'temporary_additional_texts';
  static const String DOCUMENT_ID = 'current_texts';

  // Firebase Pfad für die Standardtexte
  static const String DEFAULT_TEXTS_PATH = 'general_data/additional_texts';

  // Cache für die Standardtexte aus Firebase
  static Map<String, Map<String, Map<String, String>>>? _cachedDefaultTexts;


  static const Map<String, Map<String, String>> FALLBACK_ORIGIN_DECLARATION_TEXT = {
    'DE': {
      'standard': 'Der Unterzeichnende erklärt, dass die in diesem Dokument genannten Waren Ursprungswaren im Sinne der Ursprungsbestimmungen im Präferenzverkehr mit der Schweiz sind.',
    },
    'EN': {
      'standard': 'The undersigned hereby declares that the goods mentioned in this document are originating products within the meaning of the rules of origin in preferential trade with Switzerland.',
    },
  };

  static const Map<String, Map<String, String>> FALLBACK_CITES_TEXT = {
    'DE': {
      'standard': 'Die gelieferten Waren stehen NICHT auf der CITES-Liste (Washingtoner Artenschutzabkommen).',
    },
    'EN': {
      'standard': 'The delivered goods are NOT listed in the CITES convention (Washington Convention on International Trade in Endangered Species).',
    },
  };

  // Fallback-Texte (nur für den Fall, dass Firebase nicht erreichbar ist)
  static const Map<String, Map<String, String>> FALLBACK_LEGEND_TEXT = {
    'DE': {
      'standard': 'Legende: Urs = Ursprung (ISO-Code Nation), °C = thermobehandelt (max. Temp. in °C)',
    },
    'EN': {
      'standard': 'Legend: Orig = Origin (ISO country code), °C = heat treated (max. temp. in °C)',
    },
  };

  static const Map<String, Map<String, String>> FALLBACK_FSC_TEXT = {
    'DE': {
      'standard': 'Nur eindeutig als FSC® gekennzeichnete Artikel sind FSC®100 % zertifiziert. TUVDC-COC-101112.',
    },
    'EN': {
      'standard': 'Only items clearly marked as FSC® are FSC®100 % certified. TUVDC-COC-101112.',
    },
  };

  static const Map<String, Map<String, String>> FALLBACK_NATURAL_PRODUCT_TEXT = {
    'DE': {
      'standard': 'Es handelt sich um Naturprodukte, welche leichte Qualitätsschwankungen aufweisen können.',
    },
    'EN': {
      'standard': 'These are natural products which may have slight quality variations.',
    },
  };

  static const Map<String, Map<String, String>> FALLBACK_BANK_INFO_TEXT = {
    'DE': {
      'standard': 'Kontoinhaber: Florinett AG, Tonewood Switzerland, Veja Zinols 6, CH - 7482 Berguen, IBAN: CH58 0077 4000 1195 5220 4 , Bank: Graubuendner Kantonalbank',
      'eur': 'Kontoinhaber: Florinett AG, Tonewood Switzerland, Veja Zinols 6, CH - 7482 Berguen, IBAN: CH58 0077 4000 1195 5220 4, Bank: Graubuendner Kantonalbank',
      'usd': 'Account holder: Florinett AG, Tonewood Switzerland, Veja Zinols 6, CH - 7482 Berguen, Beneficiary Bank: Graubuendner Kantonalbank, IBAN: CH58 0077 4000 1195 5220 4, CH - 7002 Chur, Swift: GRKBCH2270A',
    },
    'EN': {
      'standard': 'Account holder: Florinett AG, Tonewood Switzerland, Veja Zinols 6, CH - 7482 Berguen, IBAN: CH58 0077 4000 1195 5220 4 , Bank: Graubunden Cantonal Bank',
      'eur': 'Account holder: Florinett AG, Tonewood Switzerland, Veja Zinols 6, CH - 7482 Berguen, IBAN: CH58 0077 4000 1195 5220 4, Bank: Graubunden Cantonal Bank',
      'usd': 'Account holder: Florinett AG, Tonewood Switzerland, Veja Zinols 6, CH - 7482 Berguen, Beneficiary Bank: Graubunden Cantonal Bank, IBAN: CH58 0077 4000 1195 5220 4, CH - 7002 Chur, Swift: GRKBCH2270A',
    },
  };

  // Lade die Standardtexte aus Firebase
  static Future<void> loadDefaultTextsFromFirebase() async {
    try {
      final doc = await FirebaseFirestore.instance
          .doc(DEFAULT_TEXTS_PATH)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _cachedDefaultTexts = {
          'legend': _parseTextData(data['legend']),
          'fsc': _parseTextData(data['fsc']),
          'natural_product': _parseTextData(data['natural_product']),
          'bank_info': _parseTextData(data['bank_info']),
          'origin_declaration': _parseTextData(data['origin_declaration']),  // NEU
          'cites': _parseTextData(data['cites']),
        };
        print('Standardtexte aus Firebase geladen');
      } else {
        print('Keine Standardtexte in Firebase gefunden, verwende Fallback');
        _initializeDefaultTextsInFirebase();
      }
    } catch (e) {
      print('Fehler beim Laden der Standardtexte aus Firebase: $e');
      // Verwende Fallback-Texte bei Fehler
      _cachedDefaultTexts = null;
    }
  }

  // Hilfsmethode zum Parsen der Textdaten
  static Map<String, Map<String, String>> _parseTextData(dynamic data) {
    final Map<String, Map<String, String>> result = {};

    if (data is Map<String, dynamic>) {
      data.forEach((lang, langData) {
        if (langData is Map<String, dynamic>) {
          result[lang] = {};
          langData.forEach((key, value) {
            if (value is String) {
              result[lang]![key] = value;
            }
          });
        }
      });
    }

    return result;
  }

  // Initialisiere die Standardtexte in Firebase (nur beim ersten Mal)
  static Future<void> _initializeDefaultTextsInFirebase() async {
    try {
      await FirebaseFirestore.instance
          .doc(DEFAULT_TEXTS_PATH)
          .set({
        'legend': FALLBACK_LEGEND_TEXT,
        'fsc': FALLBACK_FSC_TEXT,
        'natural_product': FALLBACK_NATURAL_PRODUCT_TEXT,
        'bank_info': FALLBACK_BANK_INFO_TEXT,
        'origin_declaration': FALLBACK_ORIGIN_DECLARATION_TEXT,  // NEU
        'cites': FALLBACK_CITES_TEXT,  // NEU
        'last_updated': FieldValue.serverTimestamp(),
      });

      print('Standardtexte in Firebase initialisiert');
      // Lade die Texte nach dem Initialisieren
      await loadDefaultTextsFromFirebase();
    } catch (e) {
      print('Fehler beim Initialisieren der Standardtexte in Firebase: $e');
    }
  }

  // Aktualisiere einen spezifischen Standardtext in Firebase
  static Future<void> updateDefaultText(
      String textType,
      String language,
      String variant,
      String newText,
      ) async {
    try {
      await FirebaseFirestore.instance
          .doc(DEFAULT_TEXTS_PATH)
          .update({
        '$textType.$language.$variant': newText,
        'last_updated': FieldValue.serverTimestamp(),
      });

      // Aktualisiere den Cache
      if (_cachedDefaultTexts != null) {
        _cachedDefaultTexts![textType] ??= {};
        _cachedDefaultTexts![textType]![language] ??= {};
        _cachedDefaultTexts![textType]![language]![variant] = newText;
      }

      print('Standardtext aktualisiert: $textType.$language.$variant');
    } catch (e) {
      print('Fehler beim Aktualisieren des Standardtexts: $e');
      throw e;
    }
  }

  // Hole die Standardtexte (mit Cache und Fallback)
  static Map<String, Map<String, String>> getDefaultText(String textType) {
    // Versuche zuerst aus dem Cache
    if (_cachedDefaultTexts != null && _cachedDefaultTexts!.containsKey(textType)) {
      return _cachedDefaultTexts![textType]!;
    }

    // Fallback zu den hartcodierten Texten
    switch (textType) {
      case 'legend':
        return FALLBACK_LEGEND_TEXT;
      case 'fsc':
        return FALLBACK_FSC_TEXT;
      case 'natural_product':
        return FALLBACK_NATURAL_PRODUCT_TEXT;
      case 'bank_info':
        return FALLBACK_BANK_INFO_TEXT;
      case 'origin_declaration':  // NEU
        return FALLBACK_ORIGIN_DECLARATION_TEXT;
      case 'cites':  // NEU
        return FALLBACK_CITES_TEXT;

      default:
        return {};
    }
  }

  // Laden der aktuellen Texte aus Firestore (temporäre Auswahl)
  static Future<Map<String, dynamic>> loadAdditionalTexts() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(COLLECTION_NAME)
          .doc(DOCUMENT_ID)
          .get();

      if (doc.exists && doc.data() != null) {
        return doc.data()!;
      }
    } catch (e) {
      print('Fehler beim Laden der Zusatztexte: $e');
    }

    // Standardwerte, wenn nichts gefunden wurde
    return {
      'legend': {
        'type': 'standard',
        'custom_text': '',
        'selected': true,
      },
      'fsc': {
        'type': 'standard',
        'custom_text': '',
        'selected': false,
      },
      'natural_product': {
        'type': 'standard',
        'custom_text': '',
        'selected': true,
      },
      'bank_info': {
        'type': 'standard',
        'custom_text': '',
        'selected': true,
      },
      'free_text': {
        'type': 'custom',
        'custom_text': '',
        'selected': false,
      },
    };
  }

  // Speichern der Texte in Firestore
  static Future<void> saveAdditionalTexts(Map<String, dynamic> texts) async {
    try {
      await FirebaseFirestore.instance
          .collection(COLLECTION_NAME)
          .doc(DOCUMENT_ID)
          .set(texts, SetOptions(merge: true));
    } catch (e) {
      print('Fehler beim Speichern der Zusatztexte: $e');
    }
  }

  // Prüfen, ob Texte ausgewählt wurden
  static Future<bool> hasTextsSelected() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(COLLECTION_NAME)
          .doc(DOCUMENT_ID)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        return data['legend']?['selected'] == true ||
            data['fsc']?['selected'] == true ||
            data['natural_product']?['selected'] == true ||
            data['bank_info']?['selected'] == true ||
            data['free_text']?['selected'] == true;
      }
    } catch (e) {
      print('Fehler beim Prüfen der Zusatztexte: $e');
    }

    return false;
  }

  // Löschen der temporären Texte
  static Future<void> clearAdditionalTexts() async {
    try {
      await FirebaseFirestore.instance
          .collection(COLLECTION_NAME)
          .doc(DOCUMENT_ID)
          .delete();
    } catch (e) {
      print('Fehler beim Löschen der Zusatztexte: $e');
    }
  }

  // Abrufen eines spezifischen Textes basierend auf den Einstellungen
  static String getTextContent(Map<String, dynamic> textSettings, String textType, {String language = 'DE'}) {
    if (textSettings['selected'] != true) {
      return '';
    }

    final type = textSettings['type'] as String? ?? 'standard';

    if (type == 'custom' && textSettings['custom_text']?.isNotEmpty == true) {
      return textSettings['custom_text'] as String;
    }

    // Hole die Standardtexte aus Firebase-Cache oder Fallback
    final defaultTexts = getDefaultText(textType);

    switch (textType) {
      case 'legend':
      case 'fsc':
      case 'natural_product':
    case 'origin_declaration':  // NEU
    case 'cites':
        return defaultTexts[language]?['standard'] ?? defaultTexts['DE']?['standard'] ?? '';
      case 'bank_info':
        return defaultTexts[language]?[type] ?? defaultTexts['DE']?[type] ?? defaultTexts['DE']?['standard'] ?? '';
      case 'free_text':
        return textSettings['custom_text'] ?? '';
      default:
        return '';
    }
  }

  // Stream für Live-Updates der Standardtexte
  static Stream<Map<String, dynamic>> streamDefaultTexts() {
    return FirebaseFirestore.instance
        .doc(DEFAULT_TEXTS_PATH)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        _cachedDefaultTexts = {
          'legend': _parseTextData(data['legend']),
          'fsc': _parseTextData(data['fsc']),
          'natural_product': _parseTextData(data['natural_product']),
          'bank_info': _parseTextData(data['bank_info']),
          'origin_declaration': _parseTextData(data['origin_declaration']),  // NEU
          'cites': _parseTextData(data['cites'])
        };
        return data;
      }
      return {};
    });
  }

  // Füge diese Methoden zur AdditionalTextsManager Klasse hinzu:

// Lade Additional Texts aus einer Quote
  static Future<Map<String, dynamic>> loadAdditionalTextsFromQuote(String quoteId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('quotes')
          .doc(quoteId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final metadata = data['metadata'] as Map<String, dynamic>? ?? {};

        if (metadata.containsKey('additionalTexts')) {
          return metadata['additionalTexts'] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      print('Fehler beim Laden der Zusatztexte aus Quote: $e');
    }

    // Standardwerte, wenn nichts gefunden wurde
    return {
      'legend': {
        'type': 'standard',
        'custom_text': '',
        'selected': true,
      },
      'fsc': {
        'type': 'standard',
        'custom_text': '',
        'selected': false,
      },
      'natural_product': {
        'type': 'standard',
        'custom_text': '',
        'selected': true,
      },
      'bank_info': {
        'type': 'standard',
        'custom_text': '',
        'selected': true,
      },
      'free_text': {
        'type': 'custom',
        'custom_text': '',
        'selected': false,
      },
    };
  }

// Speichere Additional Texts in einer Quote
  static Future<void> saveAdditionalTextsToQuote(String quoteId, Map<String, dynamic> texts) async {
    try {
      await FirebaseFirestore.instance
          .collection('quotes')
          .doc(quoteId)
          .update({
        'metadata.additionalTexts': texts,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Fehler beim Speichern der Zusatztexte in Quote: $e');
      rethrow;
    }
  }

// Prüfe ob eine Quote Additional Texts hat
  static Future<bool> quoteHasAdditionalTexts(String quoteId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('quotes')
          .doc(quoteId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final metadata = data['metadata'] as Map<String, dynamic>? ?? {};

        if (metadata.containsKey('additionalTexts')) {
          final additionalTexts = metadata['additionalTexts'] as Map<String, dynamic>;

          return additionalTexts['legend']?['selected'] == true ||
              additionalTexts['fsc']?['selected'] == true ||
              additionalTexts['natural_product']?['selected'] == true ||
              additionalTexts['bank_info']?['selected'] == true ||
              additionalTexts['free_text']?['selected'] == true;
        }
      }
    } catch (e) {
      print('Fehler beim Prüfen der Zusatztexte in Quote: $e');
    }

    return false;
  }




}

// Die showAdditionalTextsBottomSheet Funktion bleibt größtenteils gleich,
// aber wir müssen sicherstellen, dass die Standardtexte geladen wurden
void showAdditionalTextsBottomSheet(BuildContext context, {
  required ValueNotifier<bool> textsSelectedNotifier,
}) async {
  // Lade die Standardtexte aus Firebase, bevor das Sheet angezeigt wird
  await AdditionalTextsManager.loadDefaultTextsFromFirebase();

  // Der Rest der Funktion bleibt gleich...
  Map<String, dynamic> textConfig = {
    'legend': {
      'type': 'standard',
      'custom_text': '',
      'selected': true,
    },
    'fsc': {
      'type': 'standard',
      'custom_text': '',
      'selected': true,
    },
    'natural_product': {
      'type': 'standard',
      'custom_text': '',
      'selected': true,
    },
    'bank_info': {
      'type': 'standard',
      'custom_text': '',
      'selected': false,
    },
    'free_text': {
      'type': 'custom',
      'custom_text': '',
      'selected': false,
    },
  };

  // Lade bestehende Konfiguration, falls vorhanden
  AdditionalTextsManager.loadAdditionalTexts().then((loadedConfig) {
    textConfig = loadedConfig;
  });

  // TextEditingController für Freitexte
  final legendCustomController = TextEditingController();
  final fscCustomController = TextEditingController();
  final naturalProductCustomController = TextEditingController();
  final bankInfoCustomController = TextEditingController();
  final freeTextController = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        // Lade die Konfiguration nur einmal beim ersten Build
        if (textConfig['_loaded'] != true) {
          AdditionalTextsManager.loadAdditionalTexts().then((loadedConfig) {
            setState(() {
              textConfig = {
                ...loadedConfig,
                '_loaded': true,
              };

              // Setze die Controller auf die geladenen Werte
              legendCustomController.text = textConfig['legend']?['custom_text'] ?? '';
              fscCustomController.text = textConfig['fsc']?['custom_text'] ?? '';
              naturalProductCustomController.text = textConfig['natural_product']?['custom_text'] ?? '';
              bankInfoCustomController.text = textConfig['bank_info']?['custom_text'] ?? '';
              freeTextController.text = textConfig['free_text']?['custom_text'] ?? '';
            });
          });
        }

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Column(
              children: [
                // Drag Handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: getAdaptiveIcon(
                          iconName: 'text_fields',
                          defaultIcon: Icons.text_fields,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Zusatztexte',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Informationstext
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        getAdaptiveIcon(
                          iconName: 'info',
                          defaultIcon: Icons.info,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Wähle aus, welche Zusatztexte auf den Dokumenten erscheinen sollen.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Scrollbarer Inhalt
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // 1. Legende
                      _buildTextSection(
                        context,
                        title: 'Legende',
                        description: 'Text zur Erklärung von Abkürzungen und Symbolen',
                        isSelected: textConfig['legend']['selected'] ?? true,
                        currentType: textConfig['legend']['type'] ?? 'standard',
                        customController: legendCustomController,
                        standardText: AdditionalTextsManager.getDefaultText('legend')['DE']?['standard'] ?? '',
                        onSelectionChanged: (value) {
                          setState(() {
                            textConfig['legend']['selected'] = value;
                          });
                        },
                        onTypeChanged: (value) {
                          setState(() {
                            textConfig['legend']['type'] = value;
                          });
                        },
                        onCustomTextChanged: (value) {
                          textConfig['legend']['custom_text'] = value;
                        },
                      ),

                      const SizedBox(height: 24),

                      // 2. FSC
                      _buildTextSection(
                        context,
                        title: 'FSC-Zertifizierung',
                        description: 'Hinweis zur FSC-Zertifizierung',
                        isSelected: textConfig['fsc']['selected'] ?? false,
                        currentType: textConfig['fsc']['type'] ?? 'standard',
                        customController: fscCustomController,
                        standardText: AdditionalTextsManager.getDefaultText('fsc')['DE']?['standard'] ?? '',
                        onSelectionChanged: (value) {
                          setState(() {
                            textConfig['fsc']['selected'] = value;
                          });
                        },
                        onTypeChanged: (value) {
                          setState(() {
                            textConfig['fsc']['type'] = value;
                          });
                        },
                        onCustomTextChanged: (value) {
                          textConfig['fsc']['custom_text'] = value;
                        },
                      ),

                      const SizedBox(height: 24),

                      // 3. Naturprodukt
                      _buildTextSection(
                        context,
                        title: 'Naturprodukt',
                        description: 'Hinweis zu natürlichen Materialeigenschaften',
                        isSelected: textConfig['natural_product']['selected'] ?? true,
                        currentType: textConfig['natural_product']['type'] ?? 'standard',
                        customController: naturalProductCustomController,
                        standardText: AdditionalTextsManager.getDefaultText('natural_product')['DE']?['standard'] ?? '',
                        onSelectionChanged: (value) {
                          setState(() {
                            textConfig['natural_product']['selected'] = value;
                          });
                        },
                        onTypeChanged: (value) {
                          setState(() {
                            textConfig['natural_product']['type'] = value;
                          });
                        },
                        onCustomTextChanged: (value) {
                          textConfig['natural_product']['custom_text'] = value;
                        },
                      ),

                      const SizedBox(height: 24),

                      // 4. Bankverbindung
                      _buildTextSection(
                        context,
                        title: 'Bankverbindung',
                        description: 'Angaben zur Zahlung',
                        isSelected: textConfig['bank_info']['selected'] ?? true,
                        currentType: textConfig['bank_info']['type'] ?? 'standard',
                        customController: bankInfoCustomController,
                        standardText: AdditionalTextsManager.getDefaultText('bank_info')['DE']?['standard'] ?? '',
                        extraOptions: [
                          {'value': 'standard', 'label': 'CHF (Standard)'},
                          {'value': 'eur', 'label': 'EUR'},
                          {'value': 'usd', 'label': 'USD'},
                        ],
                        onSelectionChanged: (value) {
                          setState(() {
                            textConfig['bank_info']['selected'] = value;
                          });
                        },
                        onTypeChanged: (value) {
                          setState(() {
                            textConfig['bank_info']['type'] = value;
                          });
                        },
                        onCustomTextChanged: (value) {
                          textConfig['bank_info']['custom_text'] = value;
                        },
                      ),

                      const SizedBox(height: 24),

                      // 5. Freitext
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (textConfig['free_text']?['selected'] ?? false)
                                ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                                : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                            width: (textConfig['free_text']?['selected'] ?? false) ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Freitext',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: textConfig['free_text']?['selected'] ?? false,
                                  onChanged: (value) {
                                    setState(() {
                                      if (textConfig['free_text'] == null) {
                                        textConfig['free_text'] = {
                                          'type': 'custom',
                                          'custom_text': '',
                                          'selected': false,
                                        };
                                      }
                                      textConfig['free_text']['selected'] = value;
                                    });
                                  },
                                  activeColor: Theme.of(context).colorScheme.primary,
                                ),
                              ],
                            ),
                            if (textConfig['free_text']?['selected'] == true) ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: freeTextController,
                                decoration: const InputDecoration(
                                  labelText: 'Eigener Text',
                                  border: OutlineInputBorder(),
                                  helperText: 'Gib hier deinen eigenen Text ein, der auf den Dokumenten erscheinen soll.',
                                ),
                                maxLines: 3,
                                onChanged: (value) {
                                  if (textConfig['free_text'] == null) {
                                    textConfig['free_text'] = {
                                      'type': 'custom',
                                      'custom_text': '',
                                      'selected': true,
                                    };
                                  }
                                  textConfig['free_text']['custom_text'] = value;
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Footer mit Buttons
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Abbrechen'),
                        ),
                        const SizedBox(width: 12),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () async {
                            // Aktualisiere die custom_text Werte, falls nötig
                            textConfig['legend']['custom_text'] = legendCustomController.text;
                            textConfig['fsc']['custom_text'] = fscCustomController.text;
                            textConfig['natural_product']['custom_text'] = naturalProductCustomController.text;
                            textConfig['bank_info']['custom_text'] = bankInfoCustomController.text;
                            textConfig['free_text']['custom_text'] = freeTextController.text;

                            // Speichere die Konfiguration
                            await AdditionalTextsManager.saveAdditionalTexts(textConfig);

                            // Aktualisiere den Notifier
                            final hasSelection = textConfig['legend']['selected'] == true ||
                                textConfig['fsc']['selected'] == true ||
                                textConfig['natural_product']['selected'] == true ||
                                textConfig['bank_info']['selected'] == true ||
                                textConfig['free_text']['selected'] == true;
                            textsSelectedNotifier.value = hasSelection;

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Zusatztexte gespeichert'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                          icon: getAdaptiveIcon(
                            iconName: 'save',
                            defaultIcon: Icons.save,
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
          ),
        );
      },
    ),
  );
}

// Hilfsfunktion zum Erstellen einer Textsektion (bleibt gleich)
Widget _buildTextSection(
    BuildContext context, {
      required String title,
      required String description,
      required bool isSelected,
      required String currentType,
      required TextEditingController customController,
      required String standardText,
      List<Map<String, String>>? extraOptions,
      required Function(bool) onSelectionChanged,
      required Function(String) onTypeChanged,
      required Function(String) onCustomTextChanged,
    }) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isSelected
            ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
            : Theme.of(context).colorScheme.outline.withOpacity(0.2),
        width: isSelected ? 2 : 1,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header mit Checkbox
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Switch(
              value: isSelected,
              onChanged: onSelectionChanged,
              activeColor: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),

        if (isSelected) ...[
          const SizedBox(height: 8),

          // Optionen für Texttyp
          if (extraOptions != null && extraOptions.isNotEmpty) ...[
            // Dropdown für mehrere Optionen
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Textvorlage',
                border: OutlineInputBorder(),
              ),
              value: currentType,
              items: [
                ...extraOptions.map((option) => DropdownMenuItem(
                  value: option['value'],
                  child: Text(option['label'] ?? option['value'] ?? ''),
                )),
                const DropdownMenuItem(
                  value: 'custom',
                  child: Text('Eigener Text'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  onTypeChanged(value);
                }
              },
            ),
          ] else ...[
            // Radio-Buttons für Standard/Eigener Text
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Standard'),
                    value: 'standard',
                    groupValue: currentType,
                    onChanged: (value) {
                      if (value != null) {
                        onTypeChanged(value);
                      }
                    },
                    activeColor: Theme.of(context).colorScheme.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Eigener Text'),
                    value: 'custom',
                    groupValue: currentType,
                    onChanged: (value) {
                      if (value != null) {
                        onTypeChanged(value);
                      }
                    },
                    activeColor: Theme.of(context).colorScheme.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Vorschau des Standardtexts oder Textfeld für eigenen Text
          if (currentType == 'custom') ...[
            TextFormField(
              controller: customController,
              decoration: const InputDecoration(
                labelText: 'Eigener Text',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: onCustomTextChanged,
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vorschau:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Für die Bankverbindung ist die Logik speziell
                  Text(
                    extraOptions != null && currentType != 'standard'
                        ? (AdditionalTextsManager.getDefaultText('bank_info')['DE']?[currentType] ?? standardText)
                        : standardText,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    ),
  );
}