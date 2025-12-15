import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../constants.dart';
import '../../services/icon_helper.dart';

class RoundwoodEntryScreen extends StatefulWidget {
  final bool editMode;
  final Map<String, dynamic>? roundwoodData;
  final String? documentId;

  const RoundwoodEntryScreen({
    Key? key,
    this.editMode = false,
    this.roundwoodData,
    this.documentId,
  }) : super(key: key);

  @override
  RoundwoodEntryScreenState createState() => RoundwoodEntryScreenState();
}

class RoundwoodEntryScreenState extends State<RoundwoodEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _lastInternalNumber;
  bool _isNumberTaken = false;

  // Controllers
  final _internalNumberController = TextEditingController();
  final _originalNumberController = TextEditingController();
  final _plaketteColorController = TextEditingController();
  final _remarksController = TextEditingController();
  final _volumeController = TextEditingController();
  final _originController = TextEditingController();
  final _customYearController = TextEditingController();
  final _otherPurposeController = TextEditingController();

  // Selections
  DateTime? _selectedDate;
  bool _isMoonwood = false;
  bool _isFSC = false;
  String? _selectedWoodType;
  String? _selectedQuality;
  String? _selectedSprayColor;
  int _selectedYear = DateTime.now().year;
  bool _showCustomYearInput = false;
  bool _showAllQualities = false;

  // Verwendungszwecke (hardcoded)
  final List<String> _purposes = ['Gitarre', 'Violine', 'Viola', 'Cello', 'Bass'];
  List<String> _selectedPurposes = [];
  bool _hasOtherPurpose = false;

  // Farben für Spray
  final List<String> _sprayColors = ['ohne', 'blau', 'gelb', 'rot', 'grün'];

  // Qualitäten (primär + erweitert)
  final List<String> _primaryQualities = ['A', 'B', 'C', 'D', 'AB', 'BC', 'undefiniert'];
  List<QueryDocumentSnapshot>? _allQualities;

  // Dropdown data
  List<QueryDocumentSnapshot>? woodTypes;

  @override
  void initState() {
    super.initState();
    _loadDropdownData();
    _loadLastInternalNumber();
    if (widget.editMode && widget.roundwoodData != null) {
      _loadExistingData();
    }
    _internalNumberController.addListener(_validateInternalNumber);
  }

  Future<void> _loadLastInternalNumber() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('general_data')
          .doc('roundwood')
          .get();

      if (doc.exists && doc.data()?['last_internal_number'] != null) {
        setState(() {
          _lastInternalNumber = doc.data()?['last_internal_number'].toString().padLeft(3, '0');
          if (!widget.editMode) {
            _internalNumberController.text =
                (int.parse(_lastInternalNumber!) + 1).toString().padLeft(3, '0');
          }
        });
      } else {
        setState(() {
          _lastInternalNumber = '001';
          if (!widget.editMode) {
            _internalNumberController.text = '001';
          }
        });
      }
    } catch (e) {
      print('Fehler beim Laden der letzten Nummer: $e');
    }
  }

  Future<void> _validateInternalNumber() async {
    if (_internalNumberController.text.isEmpty) return;
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('roundwood')
          .where('internal_number', isEqualTo: _internalNumberController.text.padLeft(3, '0'))
          .where('year', isEqualTo: _selectedYear)
          .get();

      setState(() {
        _isNumberTaken = querySnapshot.docs.isNotEmpty;
        if (widget.editMode && widget.roundwoodData != null) {
          _isNumberTaken = _isNumberTaken && querySnapshot.docs.first.id != widget.documentId;
        }
      });
    } catch (e) {
      print('Fehler bei der Nummernvalidierung: $e');
    }
  }

  Future<void> _loadDropdownData() async {
    try {
      final woodTypesSnapshot = await FirebaseFirestore.instance
          .collection('wood_types')
          .orderBy('code')
          .get();

      final qualitiesSnapshot = await FirebaseFirestore.instance
          .collection('qualities')
          .orderBy('code')
          .get();

      if (!mounted) return;
      setState(() {
        woodTypes = woodTypesSnapshot.docs;
        _allQualities = qualitiesSnapshot.docs;
      });
    } catch (e) {
      print('Fehler beim Laden der Daten: $e');
    }
  }

  void _loadExistingData() {
    if (widget.roundwoodData == null) return;
    final data = widget.roundwoodData!;

    _internalNumberController.text = data['internal_number'] ?? '';
    _originalNumberController.text = data['original_number'] ?? '';
    _plaketteColorController.text = data['plakette_color'] ?? '';
    _remarksController.text = data['remarks'] ?? '';
    _volumeController.text = data['volume']?.toString() ?? '';
    _originController.text = data['origin'] ?? '';

    _isMoonwood = data['is_moonwood'] ?? false;
    _isFSC = data['is_fsc'] ?? false;
    _selectedWoodType = data['wood_type'];
    _selectedQuality = data['quality'];
    _selectedSprayColor = data['spray_color'];
    _selectedDate = data['cutting_date']?.toDate();
    _selectedYear = data['year'] ?? DateTime.now().year;
    _selectedPurposes = List<String>.from(data['purposes'] ?? []);
    _hasOtherPurpose = data['other_purpose']?.isNotEmpty ?? false;
    _otherPurposeController.text = data['other_purpose'] ?? '';
  }

  InputDecoration _getInputDecoration({
    required String labelText,
    required IconData icon,
    String? helperText,
  }) {
    return InputDecoration(
      labelText: labelText,
      helperText: helperText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[400]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[400]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF0F4A29), width: 2),
      ),
      filled: true,
      fillColor: Colors.grey[100],
      prefixIcon: Padding(
        padding: const EdgeInsets.all(8.0),
        child: getAdaptiveIcon(
          iconName: _getIconName(icon),
          defaultIcon: icon,
          color: const Color(0xFF0F4A29),
        ),
      ),
      labelStyle: TextStyle(color: Colors.grey[700]),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  String _getIconName(IconData icon) {
    if (icon == Icons.tag) return 'tag';
    if (icon == Icons.forest) return 'forest';
    if (icon == Icons.star) return 'star';
    if (icon == Icons.note_add) return 'note_add';
    if (icon == Icons.calendar_today) return 'calendar_today';
    if (icon == Icons.color_lens) return 'color_lens';
    if (icon == Icons.location_on) return 'location_on';
    if (icon == Icons.straighten) return 'straighten';
    if (icon == Icons.palette) return 'palette';
    if (icon == Icons.label) return 'label';
    return 'circle';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editMode ? 'Rundholz bearbeiten' : 'Neues Rundholz',
          style: headline4_0,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBasicInformationCard(),
              const SizedBox(height: 16),
              _buildAdditionalInformationCard(),
              const SizedBox(height: 24),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _saveRoundwood,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0F4A29),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          widget.editMode ? 'Änderungen speichern' : 'Speichern',
          style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildCardHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF0F4A29).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: getAdaptiveIcon(
            iconName: _getIconName(icon),
            defaultIcon: icon,
            color: const Color(0xFF0F4A29),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F4A29),
          ),
        ),
      ],
    );
  }

  // ==================== GRUNDINFORMATIONEN ====================
  Widget _buildBasicInformationCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader('Grundinformationen', Icons.format_list_numbered),
            const SizedBox(height: 24),

            // 1. Interne Nummer
            _buildInternalNumberField(),
            const SizedBox(height: 16),

            // 2. Jahrgang
            _buildYearSelector(),
            const SizedBox(height: 16),

            // 3. Original Stammnummer
            TextFormField(
              controller: _originalNumberController,
              decoration: _getInputDecoration(labelText: 'Original Stammnummer', icon: Icons.tag),
              maxLength: 5,
              validator: (v) => v?.isEmpty ?? true ? 'Pflichtfeld' : null,
            ),
            const SizedBox(height: 16),

            // 4. Farbe/Spray
            _buildSprayColorSelector(),
            const SizedBox(height: 16),

            // 5. Holzart
            _buildWoodTypeDropdown(),
            const SizedBox(height: 16),

            // 6. Qualität
            _buildQualitySelector(),
            const SizedBox(height: 16),

            // 7. Farbe Plakette
            TextFormField(
              controller: _plaketteColorController,
              decoration: _getInputDecoration(labelText: 'Farbe Plakette', icon: Icons.label),
            ),
            const SizedBox(height: 16),

            // 8. Einschnittdatum
            _buildDateSelector(),
            const SizedBox(height: 16),

            // 9. Verwendungszwecke
            _buildPurposeSelector(),
            const SizedBox(height: 16),

            // 10. Bemerkungen
            TextFormField(
              controller: _remarksController,
              decoration: _getInputDecoration(labelText: 'Bemerkungen', icon: Icons.note_add),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // 11. Mondholz
            _buildSwitchTile('Mondholz', Icons.nightlight, _isMoonwood, (v) => setState(() => _isMoonwood = v)),
          ],
        ),
      ),
    );
  }

  Widget _buildInternalNumberField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _internalNumberController,
          decoration: _getInputDecoration(
            labelText: 'Interne Nummer',
            icon: Icons.tag,
            helperText: 'Letzte verwendete Nummer: ${_lastInternalNumber ?? "keine"}',
          ).copyWith(
            errorText: _isNumberTaken ? 'Diese Nummer ist bereits vergeben!' : null,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _isNumberTaken ? Colors.red : Colors.grey[400]!,
                width: _isNumberTaken ? 2 : 1,
              ),
            ),
          ),
          maxLength: 3,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) {
            if (v?.isEmpty ?? true) return 'Pflichtfeld';
            if (_isNumberTaken) return 'Nummer bereits vergeben';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildYearSelector() {
    int currentYear = DateTime.now().year;
    List<int> years = [

      currentYear - 1,
      currentYear,
      currentYear + 1,

    ];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[400]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[100],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              getAdaptiveIcon(iconName: 'date_range', defaultIcon: Icons.date_range, color: const Color(0xFF0F4A29)),
              const SizedBox(width: 8),
              const Text('Jahrgang', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ...years.map((year) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _buildYearChip(year),
                ),
              )),
              const SizedBox(width: 4),
              _buildCustomYearButton(),
            ],
          ),
          if (_showCustomYearInput) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _customYearController,
                    decoration: const InputDecoration(
                      hintText: 'YYYY',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (_customYearController.text.length == 4) {
                      setState(() {
                        _selectedYear = int.parse(_customYearController.text);
                        _showCustomYearInput = false;
                      });
                      _validateInternalNumber();
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F4A29)),
                  child: const Text('OK', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildYearChip(int year) {
    bool isSelected = _selectedYear == year;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedYear = year;
          _showCustomYearInput = false;
        });
        _validateInternalNumber();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F4A29).withOpacity(0.15) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F4A29) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            '$year',
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? const Color(0xFF0F4A29) : Colors.grey[800],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomYearButton() {
    bool isCustomSelected = !([
      DateTime.now().year - 3,
      DateTime.now().year - 2,
      DateTime.now().year - 1,
      DateTime.now().year,
      DateTime.now().year + 1,
      DateTime.now().year + 2,
    ].contains(_selectedYear));

    return InkWell(
      onTap: () => setState(() => _showCustomYearInput = !_showCustomYearInput),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isCustomSelected ? const Color(0xFF0F4A29).withOpacity(0.15) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCustomSelected ? const Color(0xFF0F4A29) : Colors.grey[300]!,
            width: isCustomSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_calendar, size: 18, color: isCustomSelected ? const Color(0xFF0F4A29) : Colors.grey[600]),
            if (isCustomSelected) ...[
              const SizedBox(width: 4),
              Text('$_selectedYear', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F4A29))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSprayColorSelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[400]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[100],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              getAdaptiveIcon(iconName: 'color_lens', defaultIcon: Icons.color_lens, color: const Color(0xFF0F4A29)),
              const SizedBox(width: 8),
              const Text('Farbe/Spray', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: _sprayColors.map((color) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildColorButton(color),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildColorButton(String color) {
    bool isSelected = _selectedSprayColor == color;
    bool isNone = color == 'ohne';
    Color btnColor = isNone ? Colors.grey[200]! : _getColorFromString(color);
    bool isNarrow = MediaQuery.of(context).size.width < 600;

    return InkWell(
      onTap: () => setState(() => _selectedSprayColor = isSelected ? null : color),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: isNarrow && !isNone ? 4 : 8),
        decoration: BoxDecoration(
          color: btnColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey[400]!,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(color: btnColor.withOpacity(0.5), blurRadius: 8, spreadRadius: 1),
          ] : null,
        ),
        child: Center(
          child: isNarrow && !isNone
              ? (isSelected
              ? const Icon(Icons.check, size: 18, color: Colors.black87)
              : const SizedBox(height: 18))
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected) ...[
                const Icon(Icons.check, size: 18, color: Colors.black87),
                const SizedBox(width: 4),
              ],
              Text(
                isNone ? 'ohne' : color,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  // Hilfsfunktion zum Bereinigen von Holzartnamen
  String _cleanWoodName(String name) {
    return name.replaceAll(RegExp(r'\bGemeine\s+', caseSensitive: false), '').trim();
  }

  Widget _buildWoodTypeDropdown() {
    if (woodTypes == null) return const SizedBox.shrink();
    return DropdownButtonFormField<String>(
      decoration: _getInputDecoration(labelText: 'Holzart', icon: Icons.forest),
      value: _selectedWoodType,
      items: woodTypes!.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final displayName = _cleanWoodName(data['name'] as String);
        return DropdownMenuItem<String>(
          value: data['code'] as String,
          child: Text('$displayName (${data['code']})', style: const TextStyle(color: Colors.black87)),
        );
      }).toList(),
      onChanged: (v) => setState(() => _selectedWoodType = v),
      validator: (v) => v == null ? 'Pflichtfeld' : null,
    );
  }

  Widget _buildQualitySelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[400]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[100],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              getAdaptiveIcon(iconName: 'star', defaultIcon: Icons.star, color: const Color(0xFF0F4A29)),
              const SizedBox(width: 8),
              const Text('Qualität', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_selectedQuality != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F4A29),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(_selectedQuality!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _primaryQualities.map((q) => _buildQualityChip(q)).toList(),
          ),
          if (_showAllQualities && _allQualities != null) ...[
            const Divider(height: 24),
            const Text('Weitere Qualitäten:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allQualities!
                  .where((doc) => !_primaryQualities.contains((doc.data() as Map)['code']))
                  .map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _buildQualityChip(data['code'] as String, name: data['name'] as String?);
              }).toList(),
            ),
          ],
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _showAllQualities = !_showAllQualities),
              icon: Icon(_showAllQualities ? Icons.expand_less : Icons.expand_more, size: 18),
              label: Text(_showAllQualities ? 'Weniger anzeigen' : 'Weitere Qualitäten'),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityChip(String code, {String? name}) {
    bool isSelected = _selectedQuality == code;
    return InkWell(
      onTap: () => setState(() => _selectedQuality = code),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F4A29) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF0F4A29) : Colors.grey[300]!),
        ),
        child: Text(
          name != null ? '$code ($name)' : code,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: () => _selectDate(context),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[100],
        ),
        child: ListTile(
          leading: getAdaptiveIcon(iconName: 'calendar_today', defaultIcon: Icons.calendar_today, color: const Color(0xFF0F4A29)),
          title: Text(
            _selectedDate == null ? 'Kein Datum ausgewählt' : DateFormat('dd.MM.yyyy').format(_selectedDate!),
            style: TextStyle(color: _selectedDate == null ? Colors.grey[600] : Colors.black87),
          ),
          subtitle: Text('Einschnittdatum', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          trailing: getAdaptiveIcon(iconName: 'arrow_drop_down', defaultIcon: Icons.arrow_drop_down, color: Colors.grey[600]),
        ),
      ),
    );
  }

  Widget _buildPurposeSelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[400]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[100],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              getAdaptiveIcon(iconName: 'assignment', defaultIcon: Icons.assignment, color: const Color(0xFF0F4A29)),
              const SizedBox(width: 8),
              const Text('Verwendungszwecke', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._purposes.map((p) => _buildPurposeChip(p)),
              _buildOtherPurposeChip(),
            ],
          ),
          if (_hasOtherPurpose) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _otherPurposeController,
              decoration: const InputDecoration(
                hintText: 'Andere Verwendung beschreiben...',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPurposeChip(String purpose) {
    bool isSelected = _selectedPurposes.contains(purpose);
    return FilterChip(
      label: Text(purpose),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedPurposes.add(purpose);
          } else {
            _selectedPurposes.remove(purpose);
          }
        });
      },
      selectedColor: const Color(0xFF0F4A29).withOpacity(0.2),
      checkmarkColor: const Color(0xFF0F4A29),
      labelStyle: TextStyle(color: isSelected ? const Color(0xFF0F4A29) : Colors.black87),
    );
  }

  Widget _buildOtherPurposeChip() {
    return FilterChip(
      label: const Text('andere'),
      selected: _hasOtherPurpose,
      onSelected: (selected) => setState(() => _hasOtherPurpose = selected),
      selectedColor: const Color(0xFF0F4A29).withOpacity(0.2),
      checkmarkColor: const Color(0xFF0F4A29),
      labelStyle: TextStyle(color: _hasOtherPurpose ? const Color(0xFF0F4A29) : Colors.black87),
    );
  }

  Widget _buildSwitchTile(String title, IconData icon, bool value, Function(bool) onChanged) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[400]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[100],
      ),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
        value: value,
        onChanged: onChanged,
        secondary: getAdaptiveIcon(iconName: _getIconName(icon), defaultIcon: icon, color: const Color(0xFF0F4A29)),
        activeColor: const Color(0xFF0F4A29),
      ),
    );
  }

  // ==================== WEITERE INFORMATIONEN ====================
  Widget _buildAdditionalInformationCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader('Weitere Informationen', Icons.more_horiz),
            const SizedBox(height: 8),
            Text(
              'Diese Informationen können später ergänzt werden.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 16),

            // 1. Volumen
            TextFormField(
              controller: _volumeController,
              decoration: _getInputDecoration(labelText: 'Volumen (m³)', icon: Icons.straighten),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            ),
            const SizedBox(height: 16),

            // 2. Herkunft/Holzschlag
            TextFormField(
              controller: _originController,
              decoration: _getInputDecoration(labelText: 'Herkunft / Holzschlag', icon: Icons.location_on),
            ),
            const SizedBox(height: 16),

            // 3. FSC
            _buildSwitchTile('FSC', Icons.eco, _isFSC, (v) => setState(() => _isFSC = v)),
          ],
        ),
      ),
    );
  }

  Color _getColorFromString(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'rot': return Colors.red[200]!;
      case 'blau': return Colors.blue[200]!;
      case 'grün': return Colors.green[200]!;
      case 'gelb': return Colors.yellow[200]!;
      default: return Colors.grey[100]!;
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveRoundwood() async {
    if (_isNumberTaken) {
      AppToast.show(message: 'Die interne Nummer ${_internalNumberController.text} ist bereits vergeben!', height: h);
      return;
    }
    if (_formKey.currentState!.validate()) {
      try {
        final roundwoodData = {
          'internal_number': _internalNumberController.text.padLeft(3, '0'),
          'year': _selectedYear,
          'original_number': _originalNumberController.text,
          'spray_color': _selectedSprayColor,
          'wood_type': _selectedWoodType,
          'wood_name': _selectedWoodType != null ? _getWoodName(_selectedWoodType!) : null,
          'quality': _selectedQuality,
          'plakette_color': _plaketteColorController.text,
          'cutting_date': _selectedDate,
          'purposes': _selectedPurposes,
          'other_purpose': _hasOtherPurpose ? _otherPurposeController.text : null,
          'remarks': _remarksController.text,
          'is_moonwood': _isMoonwood,
          'volume': _volumeController.text.isNotEmpty
              ? double.parse(_volumeController.text.replaceAll(',', '.'))
              : null,
          'origin': _originController.text,
          'is_fsc': _isFSC,
          'timestamp': FieldValue.serverTimestamp(),
        };

        if (widget.editMode && widget.documentId != null) {
          await FirebaseFirestore.instance.collection('roundwood').doc(widget.documentId).update(roundwoodData);
        } else {
          await FirebaseFirestore.instance.collection('roundwood').add(roundwoodData);
          await FirebaseFirestore.instance.collection('general_data').doc('roundwood').set({
            'last_internal_number': _internalNumberController.text,
            'last_updated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        if (!mounted) return;
        Navigator.pop(context);
        AppToast.show(message: 'Rundholz erfolgreich gespeichert', height: h);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Speichern: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getWoodName(String code) {
    if (woodTypes == null) return '';
    try {
      final doc = woodTypes!.firstWhere((doc) => (doc.data() as Map)['code'] == code);
      return (doc.data() as Map)['name'] as String;
    } catch (e) {
      return '';
    }
  }

  @override
  void dispose() {
    _internalNumberController.removeListener(_validateInternalNumber);
    _internalNumberController.dispose();
    _originalNumberController.dispose();
    _plaketteColorController.dispose();
    _remarksController.dispose();
    _volumeController.dispose();
    _originController.dispose();
    _customYearController.dispose();
    _otherPurposeController.dispose();
    super.dispose();
  }
}