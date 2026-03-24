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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
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
                    children: _buildTiles(context, config, setModalState),
                  ),
                ),

                // Footer
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Abbrechen'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await provider.saveAdditionalTexts(config);
                              onSaved?.call();
                              if (context.mounted) Navigator.pop(context);
                            },
                            icon: getAdaptiveIcon(
                                iconName: 'save', defaultIcon: Icons.save),
                            label: const Text('Speichern'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Tile-Builder
  // ─────────────────────────────────────────────────────────────────

  static List<Widget> _buildTiles(
      BuildContext context,
      Map<String, dynamic> config,
      StateSetter setModalState,
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
      final standardText =
          AdditionalTextsManager.getDefaultText(defaultTextKey)['DE']
          ?['standard'] ??
              '';
      final displayText =
      (currentType == 'custom' && customText.isNotEmpty)
          ? customText
          : standardText;

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
                subtitle: isSelected
                    ? Text(displayText,
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
                    config[key] ??= {
                      'type': key == 'free_text' ? 'custom' : 'standard',
                      'custom_text': '',
                      'selected': false
                    };
                    config[key]['selected'] = value;
                  });
                },
              ),
              if (isSelected) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      if (key != 'free_text') ...[
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
                    ],
                  ),
                ),
                if (currentType == 'custom')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      controller: TextEditingController(text: customText),
                      decoration: InputDecoration(
                        labelText: 'Eigener Text',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                      maxLines: 2,
                      onChanged: (value) =>
                      config[key]['custom_text'] = value,
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
}