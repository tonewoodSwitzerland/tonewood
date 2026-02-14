import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/additional_text_manager.dart';
import '../services/icon_helper.dart';

class AdminTextsEditor extends StatefulWidget {
  const AdminTextsEditor({Key? key}) : super(key: key);

  @override
  State<AdminTextsEditor> createState() => _AdminTextsEditorState();
}

class _AdminTextsEditorState extends State<AdminTextsEditor>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Für Text-Editor Tab
  String _selectedTextType = 'legend_origin';
  String _selectedLanguage = 'DE';
  final _textController = TextEditingController();
  bool _isLoading = false;
  bool _isInfoExpanded = true;
  final _scrollController = ScrollController();

  // Für Default-Aktivierungen Tab
  Map<String, bool> _defaultSelections = {};
  bool _isLoadingDefaults = true;
  bool _hasChanges = false;

  final Map<String, String> _textTypeNames = {
    'legend_origin': 'Ursprung (Legende)',
    'legend_temperature': 'Temperatur (Legende)',
    'fsc': 'FSC-Zertifizierung',
    'natural_product': 'Naturprodukt',
    'bank_info': 'Bankverbindung',
    'origin_declaration': 'Ursprungserklärung',
    'cites': 'CITES-Erklärung',
    'free_text': 'Freitext'
  };

  final Map<String, String> _textTypeDescriptions = {
    'legend_origin': 'Erklärung der Ursprungs-Abkürzung (Urs)',
    'legend_temperature': 'Erklärung der Temperatur-Abkürzung (°C)',
    'fsc': 'Hinweis zur FSC-Zertifizierung',
    'natural_product': 'Hinweis zu natürlichen Materialeigenschaften',
    'bank_info': 'Angaben zur Zahlung',
    'origin_declaration': 'Erklärung zum Warenursprung',
    'cites': 'CITES-Artenschutz Erklärung',
    'free_text': 'Benutzerdefinierter Freitext',
  };

  final Map<String, IconData> _textTypeIcons = {
    'legend_origin': Icons.public,
    'legend_temperature': Icons.thermostat,
    'fsc': Icons.eco,
    'natural_product': Icons.nature,
    'bank_info': Icons.account_balance,
    'origin_declaration': Icons.public,
    'cites': Icons.pets,
    'free_text': Icons.edit_note,
  };

  final List<String> _languages = ['DE', 'EN'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeTexts();
    _loadDefaultSelections();
  }

  Future<void> _initializeTexts() async {
    await AdditionalTextsManager.loadDefaultTextsFromFirebase();
    _loadCurrentText();
    setState(() {});
  }

  Future<void> _loadDefaultSelections() async {
    setState(() => _isLoadingDefaults = true);
    try {
      final selections = await AdditionalTextsManager.loadDefaultSelections();
      setState(() {
        _defaultSelections = Map.from(selections);
        _isLoadingDefaults = false;
        _hasChanges = false;
      });
    } catch (e) {
      setState(() => _isLoadingDefaults = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _loadCurrentText() {
    final defaultTexts = AdditionalTextsManager.getDefaultText(_selectedTextType);
    _textController.text = defaultTexts[_selectedLanguage]?['standard'] ?? '';
  }

  Future<void> _saveText() async {
    setState(() => _isLoading = true);
    try {
      await AdditionalTextsManager.updateDefaultText(
        _selectedTextType, _selectedLanguage, 'standard', _textController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Text gespeichert'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveDefaultSelections() async {
    setState(() => _isLoading = true);
    try {
      await AdditionalTextsManager.saveAllDefaultSelections(_defaultSelections);
      setState(() => _hasChanges = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Standard-Aktivierungen gespeichert'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
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
        title: const Text('Zusatztexte verwalten'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.edit_document), text: 'Texte bearbeiten'),
            Tab(icon: Icon(Icons.toggle_on), text: 'Standard-Aktivierung'),
          ],
        ),
        actions: [
          IconButton(
            icon: getAdaptiveIcon(iconName: 'refresh', defaultIcon: Icons.refresh),
            onPressed: () async {
              await AdditionalTextsManager.loadDefaultTextsFromFirebase();
              await _loadDefaultSelections();
              _loadCurrentText();
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Daten neu geladen')),
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTextEditorTab(),
          _buildDefaultSelectionsTab(),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: Text-Editor (wie vorher)
  // ==========================================
  Widget _buildTextEditorTab() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info-Karte (einklappbar)
          _buildInfoCard(
            'Hier kannst du die Standardtexte bearbeiten. '
                'Diese werden als Vorlagen verwendet, wenn "Standard" ausgewählt ist.',
          ),
          const SizedBox(height: 24),

          // Texttyp-Auswahl
          Text('Texttyp auswählen', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedTextType,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            items: _textTypeNames.entries.map((e) => DropdownMenuItem(
              value: e.key, child: Text(e.value),
            )).toList(),
            onChanged: (v) {
              if (v != null) setState(() { _selectedTextType = v; _loadCurrentText(); });
            },
          ),
          const SizedBox(height: 16),

          // Sprache
          Text('Sprache', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: _languages.map((lang) => Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(lang),
                selected: _selectedLanguage == lang,
                onSelected: (s) {
                  if (s) setState(() { _selectedLanguage = lang; _loadCurrentText(); });
                },
              ),
            )).toList(),
          ),
          const SizedBox(height: 24),

          // Bankverbindung Varianten
          if (_selectedTextType == 'bank_info') ...[
            _buildBankVariantsCard(),
            const SizedBox(height: 24),
          ],

          // Textfeld
          Text('Text bearbeiten', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 300,
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
                if (_isInfoExpanded) setState(() => _isInfoExpanded = false);
              },
            ),
          ),
          const SizedBox(height: 16),

          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: _loadCurrentText, child: const Text('Zurücksetzen')),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveText,
                icon: _isLoading
                    ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: const Text('Speichern'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: Standard-Aktivierungen (NEU)
  // ==========================================
  Widget _buildDefaultSelectionsTab() {
    if (_isLoadingDefaults) {
      return const Center(child: CircularProgressIndicator());
    }

    final allTypes = ['legend_origin', 'legend_temperature', 'fsc', 'natural_product', 'bank_info',
      'origin_declaration', 'cites', 'free_text'];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Info-Karte
              Card(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Lege fest, welche Zusatztexte standardmäßig aktiviert sind, '
                              'wenn ein neues Dokument erstellt wird.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Aktivierungen
              ...allTypes.map((type) => _buildSelectionTile(type)),
            ],
          ),
        ),

        // Footer mit Speichern-Button
        if (_hasChanges)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Icon(Icons.warning_amber,
                      color: Theme.of(context).colorScheme.tertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ungespeicherte Änderungen',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.tertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadDefaultSelections,
                    child: const Text('Verwerfen'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveDefaultSelections,
                    icon: _isLoading
                        ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save),
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
    );
  }

  Widget _buildSelectionTile(String type) {
    final name = _textTypeNames[type] ?? type;
    final desc = _textTypeDescriptions[type] ?? '';
    final icon = _textTypeIcons[type] ?? Icons.text_fields;
    final isActive = _defaultSelections[type] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(desc, style: const TextStyle(fontSize: 12)),
        value: isActive,
        onChanged: (value) {
          setState(() {
            _defaultSelections[type] = value;
            _hasChanges = true;
          });
        },
      ),
    );
  }

  Widget _buildInfoCard(String text) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        child: InkWell(
          onTap: () => setState(() => _isInfoExpanded = !_isInfoExpanded),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.info, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedCrossFade(
                    firstChild: Text(text, style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    )),
                    secondChild: Text('Info anzeigen', style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    )),
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
    );
  }

  Widget _buildBankVariantsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance,
                    color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text('Bankverbindung Varianten',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            StreamBuilder<Map<String, dynamic>>(
              stream: AdditionalTextsManager.streamDefaultTexts(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final bankInfo = snapshot.data!['bank_info'] as Map<String, dynamic>?;
                if (bankInfo == null) return const SizedBox();
                final langTexts = bankInfo[_selectedLanguage] as Map<String, dynamic>?;
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
    );
  }

  Widget _buildBankVariantTile(String title, String variant, Map<String, dynamic> texts) {
    return ListTile(
      dense: true,
      title: Text(title),
      trailing: IconButton(
        icon: const Icon(Icons.edit, size: 20),
        onPressed: () => _showEditBankVariantDialog(title, variant, texts[variant] ?? ''),
      ),
      onTap: () => _textController.text = texts[variant] ?? '',
    );
  }

  void _showEditBankVariantDialog(String title, String variant, String currentText) {
    final controller = TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () async {
              try {
                await AdditionalTextsManager.updateDefaultText(
                  'bank_info', _selectedLanguage, variant, controller.text,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gespeichert'), backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
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
    _tabController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}