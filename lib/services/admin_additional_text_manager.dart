import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/additional_text_manager.dart';
import '../services/icon_helper.dart';

class AdminTextsEditor extends StatefulWidget {
  const AdminTextsEditor({Key? key}) : super(key: key);

  @override
  State<AdminTextsEditor> createState() => _AdminTextsEditorState();
}

class _AdminTextsEditorState extends State<AdminTextsEditor> {
  String _selectedTextType = 'legend';
  String _selectedLanguage = 'DE';
  final _textController = TextEditingController();
  bool _isLoading = false;
  bool _isInfoExpanded = true;  // NEU: Für einklappbaren Info-Bereich
  final _scrollController = ScrollController();  // NEU: Für Scroll-Funktionalität

  final Map<String, String> _textTypeNames = {
    'legend': 'Legende',
    'fsc': 'FSC-Zertifizierung',
    'natural_product': 'Naturprodukt',
    'bank_info': 'Bankverbindung',
    'origin_declaration': 'Ursprungserklärung',  // NEU
    'cites': 'CITES-Erklärung',  // NEU
  };

  final List<String> _languages = ['DE', 'EN'];

  @override
  void initState() {
    super.initState();
    _initializeTexts();
  }
  Future<void> _initializeTexts() async {
    // Lade zuerst die Texte aus Firebase
    await AdditionalTextsManager.loadDefaultTextsFromFirebase();
    // Dann lade den aktuellen Text
    _loadCurrentText();
    setState(() {}); // Trigger rebuild nach dem Laden
  }
  void _loadCurrentText() {
    final defaultTexts = AdditionalTextsManager.getDefaultText(_selectedTextType);
    final variant = _selectedTextType == 'bank_info' ? 'standard' : 'standard';
    _textController.text = defaultTexts[_selectedLanguage]?[variant] ?? '';
  }

  Future<void> _saveText() async {
    setState(() => _isLoading = true);

    try {
      final variant = _selectedTextType == 'bank_info' ? 'standard' : 'standard';
      await AdditionalTextsManager.updateDefaultText(
        _selectedTextType,
        _selectedLanguage,
        variant,
        _textController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Text erfolgreich gespeichert'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zusatztexte'),
        actions: [
          IconButton(
            icon: getAdaptiveIcon(iconName: 'refresh', defaultIcon: Icons.refresh),
            onPressed: () async {
              await AdditionalTextsManager.loadDefaultTextsFromFirebase();
              _loadCurrentText();
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Texte neu geladen'),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info-Karte
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: Card(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _isInfoExpanded = !_isInfoExpanded;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(
                          _isInfoExpanded ? Icons.info_outline : Icons.info,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AnimatedCrossFade(
                            firstChild: Text(
                              'Hier kannst du die Standardtexte für die Zusatztexte bearbeiten. '
                                  'Diese Texte werden als Vorlagen verwendet, wenn Benutzer "Standard" auswählen.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                            secondChild: Text(
                              'Zusatztexte bearbeiten',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                            crossFadeState: _isInfoExpanded
                                ? CrossFadeState.showFirst
                                : CrossFadeState.showSecond,
                            duration: const Duration(milliseconds: 300),
                          ),
                        ),
                        Icon(
                          _isInfoExpanded ? Icons.expand_less : Icons.expand_more,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Texttyp-Auswahl
            Text(
              'Texttyp auswählen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedTextType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              items: _textTypeNames.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedTextType = value;
                    _loadCurrentText();
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Sprache-Auswahl
            Text(
              'Sprache',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: _languages.map((lang) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(lang),
                    selected: _selectedLanguage == lang,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedLanguage = lang;
                          _loadCurrentText();
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Spezielle Optionen für Bankverbindung
            if (_selectedTextType == 'bank_info') ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.account_balance,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Bankverbindung Varianten',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<Map<String, dynamic>>(
                        stream: AdditionalTextsManager.streamDefaultTexts(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const CircularProgressIndicator();
                          }

                          final bankInfoTexts = snapshot.data!['bank_info'] as Map<String, dynamic>?;
                          if (bankInfoTexts == null) return const SizedBox();

                          final langTexts = bankInfoTexts[_selectedLanguage] as Map<String, dynamic>?;
                          if (langTexts == null) return const SizedBox();

                          return Column(
                            children: [
                              _buildBankVariantTile('CHF (Standard)', 'standard', langTexts),
                              _buildBankVariantTile('EUR', 'eur', langTexts),
                              _buildBankVariantTile('USD', 'usd', langTexts),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Textfeld
            Text(
              'Text bearbeiten',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Container(
              height: 300,  // Feste Höhe statt Expanded
              child: TextFormField(
                controller: _textController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: 'Text eingeben...',
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
                onTap: () {
                  // Beim Antippen des Textfelds Info-Bereich einklappen
                  if (_isInfoExpanded) {
                    setState(() {
                      _isInfoExpanded = false;
                    });
                  }
                  // Nach kurzer Verzögerung zum Textfeld scrollen
                  Future.delayed(const Duration(milliseconds: 300), () {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // Aktions-Buttons
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _loadCurrentText,
                    child: const Text('Zurücksetzen'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveText,
                    icon: _isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : getAdaptiveIcon(iconName: 'save', defaultIcon: Icons.save),
                    label: const Text('Speichern'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankVariantTile(String title, String variant, Map<String, dynamic> texts) {
    return ListTile(
      dense: true,
      title: Text(title),
      trailing: IconButton(
        icon: getAdaptiveIcon(iconName: 'edit', defaultIcon: Icons.edit, size: 20),
        onPressed: () {
          _showEditBankVariantDialog(title, variant, texts[variant] ?? '');
        },
      ),
      onTap: () {
        _textController.text = texts[variant] ?? '';
      },
    );
  }

  void _showEditBankVariantDialog(String title, String variant, String currentText) {
    final controller = TextEditingController(text: currentText);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$title bearbeiten'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Text eingeben...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await AdditionalTextsManager.updateDefaultText(
                  'bank_info',
                  _selectedLanguage,
                  variant,
                  controller.text,
                );

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Text gespeichert'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Fehler: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}