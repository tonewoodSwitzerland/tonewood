import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/icon_helper.dart';

class AdditionalTextsManager {
  static const String COLLECTION_NAME = 'temporary_additional_texts';
  static const String DOCUMENT_ID = 'current_texts';

  // Standardtexte
  // Standardtexte mit Übersetzungen
  static const Map<String, Map<String, String>> DEFAULT_LEGEND_TEXT = {
    'DE': {
      'standard': 'Legende: Urs = Ursprung (ISO-Code Nation), °C = thermobehandelt (max. Temp. in °C)',
    },
    'EN': {
      'standard': 'Legend: Urs = Origin (ISO country code), °C = heat treated (max. temp. in °C)',
    },
  };

  static const Map<String, Map<String, String>> DEFAULT_FSC_TEXT = {
    'DE': {
      'standard': 'Nur eindeutig als FSC® gekennzeichnete Artikel sind FSC® zertifiziert. TUVDC-COC-101112.',
    },
    'EN': {
      'standard': 'Only items clearly marked as FSC® are FSC® certified. TUVDC-COC-101112.',
    },
  };

  static const Map<String, Map<String, String>> DEFAULT_NATURAL_PRODUCT_TEXT = {
    'DE': {
      'standard': 'Es handelt sich um Naturprodukte, welche leichte Qualitätsschwankungen aufweisen können.',
    },
    'EN': {
      'standard': 'These are natural products which may have slight quality variations.',
    },
  };

  static const Map<String, Map<String, String>> DEFAULT_BANK_INFO_TEXT = {
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
// Neues Freitextfeld
  static const Map<String, String> DEFAULT_CUSTOM_TEXT = {
    'standard': '',
  };



  // Laden der aktuellen Texte aus Firestore
  // Laden der aktuellen Texte aus Firestore
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
      'free_text': {  // Neues Freitextfeld
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
            data['free_text']?['selected'] == true;  // Neues Feld hinzufügen
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
  // Abrufen eines spezifischen Textes basierend auf den Einstellungen
  // Abrufen eines spezifischen Textes basierend auf den Einstellungen
  static String getTextContent(Map<String, dynamic> textSettings, String textType, {String language = 'DE'}) {
    if (textSettings['selected'] != true) {
      return '';
    }

    final type = textSettings['type'] as String? ?? 'standard';

    if (type == 'custom' && textSettings['custom_text']?.isNotEmpty == true) {
      return textSettings['custom_text'] as String;
    }

    // Standardtext basierend auf dem Typ und der Sprache zurückgeben
    switch (textType) {
      case 'legend':
        return DEFAULT_LEGEND_TEXT[language]?['standard'] ?? DEFAULT_LEGEND_TEXT['DE']?['standard'] ?? '';
      case 'fsc':
        return DEFAULT_FSC_TEXT[language]?['standard'] ?? DEFAULT_FSC_TEXT['DE']?['standard'] ?? '';
      case 'natural_product':
        return DEFAULT_NATURAL_PRODUCT_TEXT[language]?['standard'] ?? DEFAULT_NATURAL_PRODUCT_TEXT['DE']?['standard'] ?? '';
      case 'bank_info':
        return DEFAULT_BANK_INFO_TEXT[language]?[type] ?? DEFAULT_BANK_INFO_TEXT['DE']?[type] ?? DEFAULT_BANK_INFO_TEXT['DE']?['standard'] ?? '';
      case 'free_text':  // Freitext hat keinen Standardtext
        return textSettings['custom_text'] ?? '';
      default:
        return '';
    }
  }
}

void showAdditionalTextsBottomSheet(BuildContext context, {
  required ValueNotifier<bool> textsSelectedNotifier,
}) {
  // Temporäre Textkonfiguration
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
    'free_text': {  // Neues Freitextfeld
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
  final freeTextController = TextEditingController();  // Neuer Controller

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
              // Überschreibe die Standardwerte mit den geladenen Werten
              textConfig = {
                ...loadedConfig,
                '_loaded': true, // Markiere als geladen
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
                            'Wähle aus, welche Zusatztexte auf den Dokumenten erscheinen sollen. ',

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
                        standardText: AdditionalTextsManager.DEFAULT_LEGEND_TEXT['DE']!['standard']!,
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
                        standardText: AdditionalTextsManager.DEFAULT_FSC_TEXT['DE']!['standard']!,  // <-- Geändert

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
                        standardText: AdditionalTextsManager.DEFAULT_NATURAL_PRODUCT_TEXT['DE']!['standard']!,
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
                          standardText: AdditionalTextsManager.DEFAULT_BANK_INFO_TEXT['DE']!['standard']!,
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
                                      // Stelle sicher, dass das free_text Objekt existiert
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
                                  // Stelle sicher, dass das free_text Objekt existiert
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
                                textConfig['bank_info']['selected'] == true
                                ||
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

// Hilfsfunktion zum Erstellen einer Textsektion
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
         //const SizedBox(height: 8),

          // // Beschreibung
          // Text(
          //   description,
          //   style: TextStyle(
          //     color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          //     fontSize: 14,
          //   ),
          // ),

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
                  // In der Vorschau-Sektion:
                  // Für die Bankverbindung ist die Logik speziell, weil es mehrere Optionen gibt
                  Text(
                    extraOptions != null && currentType != 'standard'
                        ? (AdditionalTextsManager.DEFAULT_BANK_INFO_TEXT['DE']?[currentType] ?? standardText)
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