// File: services/document_settings/additional_texts_settings_dialog.dart

import 'package:flutter/material.dart';
import '../../services/icon_helper.dart';
import '../../quotes/additional_text_manager.dart';
import 'document_settings_provider.dart';

/// Gemeinsamer Zusatztexte-Einstellungen Dialog.
///
/// Wird sowohl im Auftrags- als auch im Angebotsbereich verwendet.
/// Der [DocumentSettingsProvider] bestimmt, wohin die Daten gespeichert werden.
class AdditionalTextsSettingsDialog {
  /// Extra-Optionen für Texttypen mit mehreren Standard-Varianten.
  /// Aktuell nur Bankverbindung (CHF/EUR/USD), kann bei Bedarf erweitert werden.
  static const Map<String, List<Map<String, String>>> _extraOptions = {
    'bank_info': [
      {'value': 'standard', 'label': 'CHF (Standard)'},
      {'value': 'eur', 'label': 'EUR'},
      {'value': 'usd', 'label': 'USD'},
    ],
  };

  /// Zeigt den Zusatztexte-Dialog.
  ///
  /// [config] ist die aktuelle Zusatztexte-Konfiguration (wird in-place modifiziert).
  /// [provider] bestimmt wohin gespeichert wird.
  /// [onSaved] wird nach dem Speichern aufgerufen.
  static Future<void> show(
      BuildContext context, {
        required DocumentSettingsProvider provider,
        required Map<String, dynamic> config,
        VoidCallback? onSaved,
      }) async {
    // Firebase-Caches sicherstellen, bevor das Sheet aufgeht.
    // Ohne diesen Schritt liefert getDefaultText() den (leeren) Fallback,
    // weil _cachedDefaultTexts noch null sein kann.
    await AdditionalTextsManager.loadDefaultTextsFromFirebase();
    await AdditionalTextsManager.loadCustomTextBlocks();

    // Persistente Controller, einmal pro Texttyp.
    // Werden lazy via putIfAbsent in _buildTiles gefüllt und am Ende disposed.
    final controllers = <String, TextEditingController>{};

    // Loading-State für Speichern-Button (gegen Doppelklick)
    final isSavingNotifier = ValueNotifier<bool>(false);

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              // Schiebt den Sheet bei eingeblendeter Tastatur hoch,
              // damit das Eigener-Text-Feld nicht verdeckt wird.
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.85,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    // Drag Handle
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          getAdaptiveIcon(
                            iconName: 'text_fields',
                            defaultIcon: Icons.text_fields,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Zusatztexte',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: getAdaptiveIcon(
                                iconName: 'close', defaultIcon: Icons.close),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Diese Einstellungen gelten für alle Dokumente.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                      ),
                    ),

                    const Divider(),

                    // Content
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(24),
                        children: _buildTiles(
                          context,
                          config,
                          setModalState,
                          controllers,
                        ),
                      ),
                    ),

                    // Footer
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            Expanded(
                              child: ValueListenableBuilder<bool>(
                                valueListenable: isSavingNotifier,
                                builder: (context, isSaving, _) {
                                  return OutlinedButton(
                                    onPressed: isSaving
                                        ? null
                                        : () => Navigator.pop(context),
                                    child: const Text('Abbrechen'),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ValueListenableBuilder<bool>(
                                valueListenable: isSavingNotifier,
                                builder: (context, isSaving, _) {
                                  return ElevatedButton.icon(
                                    onPressed: isSaving
                                        ? null
                                        : () async {
                                      isSavingNotifier.value = true;
                                      try {
                                        await provider
                                            .saveAdditionalTexts(config);
                                        onSaved?.call();
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Zusatztexte gespeichert'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        isSavingNotifier.value = false;
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Fehler beim Speichern: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    icon: isSaving
                                        ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                        : getAdaptiveIcon(
                                        iconName: 'save',
                                        defaultIcon: Icons.save),
                                    label: Text(isSaving
                                        ? 'Speichern...'
                                        : 'Speichern'),
                                  );
                                },
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
    } finally {
      // Controller aufräumen
      for (final c in controllers.values) {
        c.dispose();
      }
      isSavingNotifier.dispose();
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Tile-Builder
  // ─────────────────────────────────────────────────────────────────

  static List<Widget> _buildTiles(
      BuildContext context,
      Map<String, dynamic> config,
      StateSetter setModalState,
      Map<String, TextEditingController> controllers,
      ) {
    final textTypes = [
      {'key': 'legend_origin', 'title': 'Ursprung (Legende)', 'defaultTextKey': 'legend_origin'},
      {'key': 'legend_temperature', 'title': 'Temperatur (Legende)', 'defaultTextKey': 'legend_temperature'},
      {'key': 'fsc', 'title': 'FSC-Zertifizierung', 'defaultTextKey': 'fsc'},
      {'key': 'natural_product', 'title': 'Naturprodukt', 'defaultTextKey': 'natural_product'},
      {'key': 'bank_info', 'title': 'Bankverbindung', 'defaultTextKey': 'bank_info'},
      {'key': 'free_text', 'title': 'Freitext', 'defaultTextKey': 'free_text'},
    ];

    final List<Widget> tiles = [];

    for (final type in textTypes) {
      final key = type['key']!;
      final title = type['title']!;
      final defaultTextKey = type['defaultTextKey']!;
      final isSelected = config[key]?['selected'] == true;
      final currentType = config[key]?['type'] ?? 'standard';
      final customText = config[key]?['custom_text'] ?? '';

      // Hat dieser Texttyp Extra-Optionen (z.B. Bankverbindung)?
      final extraOptions = _extraOptions[key];
      final hasExtraOptions = extraOptions != null && extraOptions.isNotEmpty;

      // Persistenter Controller (nur einmal initialisiert)
      final controller = controllers.putIfAbsent(
        key,
            () => TextEditingController(text: customText),
      );
      print('DEBUG bank_info: type=${config[key]?['type']}, full=${config[key]}');
      // Vorschautext bestimmen
      final defaultTextMap =
          AdditionalTextsManager.getDefaultText(defaultTextKey)['DE'] ?? {};
      final standardText = defaultTextMap['standard'] ?? '';

      String displayText;
      if (currentType == 'custom' && customText.isNotEmpty) {
        displayText = customText;
      } else if (hasExtraOptions && currentType != 'custom') {
        // Bei Bankverbindung: passende Variante (standard/eur/usd) anzeigen
        displayText = defaultTextMap[currentType] ?? standardText;
      } else {
        displayText = standardText;
      }

      tiles.add(
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                  : Theme.of(context).colorScheme.outline.withOpacity(0.15),
            ),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                // Subtitle entfernt — Vorschau lebt jetzt unten als eigener Container
                value: isSelected,
                dense: true,
                onChanged: (value) {
                  setModalState(() {
                    config[key] ??= {
                      'type': key == 'free_text' ? 'custom' : 'standard',
                      'custom_text': '',
                      'selected': value,
                    };
                    config[key]['selected'] = value;
                  });
                },
              ),
              if (isSelected) ...[
                // Auswahl der Variante
                if (hasExtraOptions) ...[
                  // Dropdown (z.B. für Bankverbindung mit CHF/EUR/USD/Eigener Text)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: DropdownButtonFormField<String>(
                      value: _resolveDropdownValue(currentType, extraOptions),
                      isDense: true,
                      decoration: InputDecoration(
                        labelText: 'Variante',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      items: [
                        ...extraOptions.map(
                              (option) => DropdownMenuItem<String>(
                            value: option['value'],
                            child: Text(
                              option['label'] ?? option['value'] ?? '',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                        const DropdownMenuItem<String>(
                          value: 'custom',
                          child: Text('Eigener Text',
                              style: TextStyle(fontSize: 13)),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() => config[key]['type'] = value);
                        }
                      },
                    ),
                  ),
                ] else if (key != 'free_text') ...[
                  // ChoiceChips für Standard/Eigener Text (bisheriges Verhalten)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Standard',
                              style: TextStyle(fontSize: 12)),
                          selected: currentType == 'standard',
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(
                                      () => config[key]['type'] = 'standard');
                            }
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Eigener Text',
                              style: TextStyle(fontSize: 12)),
                          selected: currentType == 'custom',
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(
                                      () => config[key]['type'] = 'custom');
                            }
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ],

                // Eigener Text - Eingabefeld ODER Vorschau-Container
                if (currentType == 'custom')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: 'Eigener Text',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                      maxLines: 4,
                      onChanged: (value) =>
                      config[key]['custom_text'] = value,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Container(
                      width: double.infinity,
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
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            displayText,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      );
    }

    // Custom Text Blocks
    final customBlocks = AdditionalTextsManager.getCachedCustomTextBlocks();
    if (customBlocks.isNotEmpty) {
      if (config['custom_blocks'] == null) {
        config['custom_blocks'] = {};
      }
      final customBlocksConfig =
      config['custom_blocks'] as Map<String, dynamic>;

      tiles.add(
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Row(
            children: [
              Icon(Icons.library_books,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Weitere Textbausteine',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      );

      for (final block in customBlocks) {
        final blockId = block['id'] as String;
        final title = block['title'] ?? '';
        final textDe = block['text_de'] ?? '';

        if (!customBlocksConfig.containsKey(blockId)) {
          customBlocksConfig[blockId] = {
            'selected': block['active_by_default'] ?? false,
          };
        }

        final isSelected =
            customBlocksConfig[blockId]?['selected'] == true;

        tiles.add(
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context)
                    .colorScheme
                    .primary
                    .withOpacity(0.3)
                    : Theme.of(context)
                    .colorScheme
                    .outline
                    .withOpacity(0.15),
              ),
            ),
            child: SwitchListTile(
              title: Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: isSelected
                  ? Text(textDe,
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis)
                  : null,
              value: isSelected,
              dense: true,
              onChanged: (value) {
                setModalState(() {
                  customBlocksConfig[blockId] = {'selected': value};
                });
              },
            ),
          ),
        );
      }
    }

    return tiles;
  }

  /// Stellt sicher, dass der Dropdown-Wert in den verfügbaren Optionen vorhanden ist.
  /// Fällt auf 'standard' zurück, falls ein unbekannter Wert in der Config steht.
  static String _resolveDropdownValue(
      String currentType, List<Map<String, String>> extraOptions) {
    final allowed = <String>{
      ...extraOptions.map((o) => o['value'] ?? ''),
      'custom',
    };
    return allowed.contains(currentType) ? currentType : 'standard';
  }
}