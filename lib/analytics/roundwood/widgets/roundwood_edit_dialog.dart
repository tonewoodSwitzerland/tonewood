import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../constants.dart';
import '../../../services/icon_helper.dart';
import '../models/roundwood_models.dart';

class RoundwoodEditDialog extends StatefulWidget {
  final RoundwoodItem item;
  final bool isDesktopLayout;

  const RoundwoodEditDialog({
    Key? key,
    required this.item,
    required this.isDesktopLayout,
  }) : super(key: key);

  @override
  RoundwoodEditDialogState createState() => RoundwoodEditDialogState();
}

class RoundwoodEditDialogState extends State<RoundwoodEditDialog> {
  late Map<String, dynamic> editedData;
  final formKey = GlobalKey<FormState>();

  // Dropdown Data
  List<QueryDocumentSnapshot>? woodTypes;
  List<QueryDocumentSnapshot>? qualities;

  // Controller für editierbare Textfelder
  final _originalNumberController = TextEditingController();
  final _plaketteColorController = TextEditingController();
  final _remarksController = TextEditingController();
  final _volumeController = TextEditingController();
  final _originController = TextEditingController();

  // Hardcoded Verwendungszwecke (wie im Entry Screen)
  final List<String> _availablePurposes = ['Gitarre', 'Violine', 'Viola', 'Cello', 'Bass'];
  List<String> _selectedPurposes = [];
  bool _hasOtherPurpose = false;
  final _otherPurposeController = TextEditingController();

  // Jahr Auswahl
  int _selectedYear = DateTime.now().year;
  bool _showCustomYearInput = false;
  final _customYearController = TextEditingController();

  // Spray Farben
  final List<String> _sprayColors = ['ohne', 'blau', 'gelb', 'rot', 'grün'];
  String? _selectedSprayColor;

  @override
  void initState() {
    super.initState();
    editedData = widget.item.toMap();
    _loadDropdownData();
    _initializeFromItem();
  }

  void _initializeFromItem() {
    _selectedYear = widget.item.year;
    _selectedSprayColor = widget.item.sprayColor;
    _selectedPurposes = List<String>.from(widget.item.purposes);

    // Controller initialisieren
    _originalNumberController.text = widget.item.originalNumber ?? '';
    _plaketteColorController.text = widget.item.plaketteColor ?? '';
    _remarksController.text = widget.item.remarks ?? '';
    _volumeController.text = widget.item.volume > 0 ? widget.item.volume.toString() : '';
    _originController.text = widget.item.origin ?? '';

    // Prüfe ob "andere" verwendet wird
    _hasOtherPurpose = widget.item.otherPurpose?.isNotEmpty ?? false;
    _otherPurposeController.text = widget.item.otherPurpose ?? '';

    // Entferne custom Einträge aus der Standard-Liste
    _selectedPurposes = _selectedPurposes.where((p) => _availablePurposes.contains(p)).toList();
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

      if (mounted) {
        setState(() {
          woodTypes = woodTypesSnapshot.docs;
          qualities = qualitiesSnapshot.docs;
        });
      }
    } catch (e) {
      print('Fehler beim Laden der Daten: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _buildDragHandle(),
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBasicInfoSection(),
                        const SizedBox(height: 24),
                        _buildAdditionalInfoSection(),
                        const SizedBox(height: 16),
                        _buildDeleteButton(),
                      ],
                    ),
                  ),
                ),
              ),
              _buildFooter(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F4A29).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: getAdaptiveIcon(
              iconName: 'forest',
              defaultIcon: Icons.forest,
              color: const Color(0xFF0F4A29),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rundholz ${widget.item.internalNumber} bearbeiten',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F4A29),
                  ),
                ),
                Text(
                  '${widget.item.woodName} • ${widget.item.year}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
          IconButton(
            icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            color: Colors.grey[600],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, String iconName) {
    return Row(
      children: [
        getAdaptiveIcon(iconName: iconName, defaultIcon: icon, size: 20, color: const Color(0xFF0F4A29)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F4A29))),
      ],
    );
  }

  Widget _buildSectionContainer(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: child,
    );
  }

  // ==================== GRUNDINFORMATIONEN ====================
  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Grundinformationen', Icons.badge, 'badge'),
        const SizedBox(height: 16),
        _buildSectionContainer(
          Column(
            children: [
              _buildInternalNumberDisplay(), // Nur Anzeige, nicht editierbar
              const SizedBox(height: 16),
              _buildOriginalNumberInput(), // Editierbar
              const SizedBox(height: 16),
              _buildYearSelector(),
              const SizedBox(height: 16),
              _buildWoodTypeDropdown(),
              const SizedBox(height: 16),
              _buildQualitySelector(),
              const SizedBox(height: 16),
              _buildSprayColorSelector(),
              const SizedBox(height: 16),
              _buildPlaketteColorInput(),
              const SizedBox(height: 16),
              _buildDatePicker(),
              const SizedBox(height: 16),
              _buildPurposeSelector(),
              const SizedBox(height: 16),
              _buildRemarksInput(),
              const SizedBox(height: 16),
              _buildMoonwoodSwitch(),
            ],
          ),
        ),
      ],
    );
  }

  // Interne Nummer - NUR ANZEIGE (nicht editierbar)
  Widget _buildInternalNumberDisplay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          getAdaptiveIcon(iconName: 'lock', defaultIcon: Icons.lock, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Interne Nummer', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                widget.item.internalNumber,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('Nicht änderbar', style: TextStyle(color: Colors.grey[700], fontSize: 10)),
          ),
        ],
      ),
    );
  }

  // Original Nummer - EDITIERBAR
  Widget _buildOriginalNumberInput() {
    return TextFormField(
      controller: _originalNumberController,
      decoration: InputDecoration(
        labelText: 'Original Stammnummer',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: getAdaptiveIcon(iconName: 'tag', defaultIcon: Icons.tag, color: const Color(0xFF0F4A29)),
      ),
      maxLength: 5,
      onChanged: (value) => editedData['original_number'] = value,
    );
  }

  Widget _buildYearSelector() {
    int currentYear = DateTime.now().year;
    List<int> years = [currentYear - 1, currentYear, currentYear + 1];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              getAdaptiveIcon(iconName: 'date_range', defaultIcon: Icons.date_range, color: const Color(0xFF0F4A29)),
              const SizedBox(width: 8),
              const Text('Jahrgang', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
                    decoration: const InputDecoration(hintText: 'YYYY', isDense: true, border: OutlineInputBorder()),
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
                        editedData['year'] = _selectedYear;
                        _showCustomYearInput = false;
                      });
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
          editedData['year'] = year;
          _showCustomYearInput = false;
        });
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
      DateTime.now().year - 1,
      DateTime.now().year,
      DateTime.now().year + 1,
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

// Hilfsfunktion zum Bereinigen von Holzartnamen
  String _cleanWoodName(String name) {
    return name.replaceAll(RegExp(r'\bGemeine\s+', caseSensitive: false), '').trim();
  }

  Widget _buildWoodTypeDropdown() {
    if (woodTypes == null) return const CircularProgressIndicator();

    return DropdownButtonFormField<String>(
      value: editedData['wood_type'],
      decoration: InputDecoration(
        labelText: 'Holzart',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: getAdaptiveIcon(iconName: 'forest', defaultIcon: Icons.forest, color: const Color(0xFF0F4A29)),
      ),
      items: woodTypes!.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final displayName = _cleanWoodName(data['name'] as String);
        return DropdownMenuItem<String>(
          value: data['code'] as String,
          child: Text('$displayName (${data['code']})'),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            editedData['wood_type'] = value;
            final rawName = woodTypes!
                .firstWhere((doc) => (doc.data() as Map<String, dynamic>)['code'] == value)
                .get('name') as String;
            editedData['wood_name'] = _cleanWoodName(rawName);
          });
        }
      },
      validator: (v) => v == null ? 'Pflichtfeld' : null,
    );
  }

  Widget _buildQualitySelector() {
    final primaryQualities = ['A', 'B', 'C', 'D', 'AB', 'BC', 'undefiniert'];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              getAdaptiveIcon(iconName: 'star', defaultIcon: Icons.star, color: const Color(0xFF0F4A29)),
              const SizedBox(width: 8),
              const Text('Qualität', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (editedData['quality'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F4A29),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(editedData['quality'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: primaryQualities.map((q) => _buildQualityChip(q)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityChip(String code) {
    bool isSelected = editedData['quality'] == code;
    return InkWell(
      onTap: () {
        setState(() {
          editedData['quality'] = code;
          editedData['quality_name'] = code;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F4A29) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF0F4A29) : Colors.grey[300]!),
        ),
        child: Text(
          code,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSprayColorSelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              getAdaptiveIcon(iconName: 'color_lens', defaultIcon: Icons.color_lens, color: const Color(0xFF0F4A29)),
              const SizedBox(width: 8),
              const Text('Farbe/Spray', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
      onTap: () {
        setState(() {
          _selectedSprayColor = isSelected ? null : color;
          editedData['spray_color'] = _selectedSprayColor;
        });
      },
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
  Widget _buildPlaketteColorInput() {
    return TextFormField(
      controller: _plaketteColorController,
      decoration: InputDecoration(
        labelText: 'Farbe Plakette',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: getAdaptiveIcon(iconName: 'label', defaultIcon: Icons.label, color: const Color(0xFF0F4A29)),
      ),
      onChanged: (value) => editedData['plakette_color'] = value,
    );
  }

  Widget _buildDatePicker() {
    final cuttingDate = editedData['cutting_date'] is Timestamp
        ? (editedData['cutting_date'] as Timestamp).toDate()
        : editedData['cutting_date'] as DateTime?;

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: cuttingDate ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          setState(() => editedData['cutting_date'] = Timestamp.fromDate(picked));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: ListTile(
          leading: getAdaptiveIcon(iconName: 'calendar_today', defaultIcon: Icons.calendar_today, color: const Color(0xFF0F4A29)),
          title: Text(
            cuttingDate == null ? 'Kein Datum ausgewählt' : DateFormat('dd.MM.yyyy').format(cuttingDate),
            style: TextStyle(color: cuttingDate == null ? Colors.grey[600] : Colors.black87),
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
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              getAdaptiveIcon(iconName: 'assignment', defaultIcon: Icons.assignment, color: const Color(0xFF0F4A29)),
              const SizedBox(width: 8),
              const Text('Verwendungszwecke', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._availablePurposes.map((p) => _buildPurposeChip(p)),
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
              onChanged: (value) => editedData['other_purpose'] = value,
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
          editedData['purposes'] = _selectedPurposes;
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

  Widget _buildRemarksInput() {
    return TextFormField(
      controller: _remarksController,
      decoration: InputDecoration(
        labelText: 'Bemerkungen',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: getAdaptiveIcon(iconName: 'note_add', defaultIcon: Icons.note_add, color: const Color(0xFF0F4A29)),
      ),
      maxLines: 3,
      onChanged: (value) => editedData['remarks'] = value,
    );
  }

  Widget _buildMoonwoodSwitch() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: SwitchListTile(
        title: const Text('Mondholz', style: TextStyle(fontWeight: FontWeight.w500)),
        value: editedData['is_moonwood'] ?? false,
        onChanged: (value) => setState(() => editedData['is_moonwood'] = value),
        secondary: getAdaptiveIcon(iconName: 'nightlight', defaultIcon: Icons.nightlight, color: const Color(0xFF0F4A29)),
        activeColor: const Color(0xFF0F4A29),
      ),
    );
  }

  // ==================== WEITERE INFORMATIONEN ====================
  Widget _buildAdditionalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Weitere Informationen', Icons.more_horiz, 'more_horiz'),
        const SizedBox(height: 8),
        Text('Diese Informationen können später ergänzt werden.', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 16),
        _buildSectionContainer(
          Column(
            children: [
              _buildVolumeInput(),
              const SizedBox(height: 16),
              _buildOriginInput(),
              const SizedBox(height: 16),
              _buildFSCSwitch(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVolumeInput() {
    return TextFormField(
      controller: _volumeController,
      decoration: InputDecoration(
        labelText: 'Volumen (m³)',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: getAdaptiveIcon(iconName: 'straighten', defaultIcon: Icons.straighten, color: const Color(0xFF0F4A29)),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      onChanged: (value) {
        editedData['volume'] = double.tryParse(value.replaceAll(',', '.'));
      },
    );
  }

  Widget _buildOriginInput() {
    return TextFormField(
      controller: _originController,
      decoration: InputDecoration(
        labelText: 'Herkunft / Holzschlag',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: getAdaptiveIcon(iconName: 'location_on', defaultIcon: Icons.location_on, color: const Color(0xFF0F4A29)),
      ),
      onChanged: (value) => editedData['origin'] = value,
    );
  }

  Widget _buildFSCSwitch() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: SwitchListTile(
        title: const Text('FSC-zertifiziert', style: TextStyle(fontWeight: FontWeight.w500)),
        value: editedData['is_fsc'] ?? false,
        onChanged: (value) => setState(() => editedData['is_fsc'] = value),
        secondary: getAdaptiveIcon(iconName: 'eco', defaultIcon: Icons.eco, color: const Color(0xFF0F4A29)),
        activeColor: const Color(0xFF0F4A29),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Center(
      child: TextButton.icon(
        icon: getAdaptiveIcon(iconName: 'delete', defaultIcon: Icons.delete, color: Colors.red),
        label: const Text('Löschen'),
        onPressed: _confirmDelete,
        style: TextButton.styleFrom(foregroundColor: Colors.red),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, -2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[700],
              side: BorderSide(color: Colors.grey[300]!),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Abbrechen'),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            icon: getAdaptiveIcon(iconName: 'save', defaultIcon: Icons.save),
            label: const Text('Speichern'),
            onPressed: _saveChanges,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F4A29),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
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

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: getAdaptiveIcon(iconName: 'warning', defaultIcon: Icons.warning, color: Colors.red),
            ),
            const SizedBox(width: 8),
            const Text('Löschen bestätigen'),
          ],
        ),
        content: Text('Möchtest du das Rundholz ${widget.item.internalNumber} wirklich löschen?\n\nDiese Aktion kann nicht rückgängig gemacht werden.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('roundwood').doc(widget.item.id).delete();
        if (!mounted) return;
        AppToast.show(message: 'Rundholz wurde gelöscht', height: h);
        Navigator.pop(context, {'action': 'delete', 'id': widget.item.id});
      } catch (e) {
        AppToast.show(message: 'Fehler beim Löschen: $e', height: h);
      }
    }
  }

  Future<void> _saveChanges() async {
    if (formKey.currentState?.validate() ?? true) {
      try {
        // Alle Werte aus Controllern übernehmen
        editedData['original_number'] = _originalNumberController.text;
        editedData['plakette_color'] = _plaketteColorController.text;
        editedData['remarks'] = _remarksController.text;
        editedData['origin'] = _originController.text;
        editedData['volume'] = double.tryParse(_volumeController.text.replaceAll(',', '.')) ?? 0.0;

        // Purposes aktualisieren
        editedData['purposes'] = _selectedPurposes;
        editedData['other_purpose'] = _hasOtherPurpose ? _otherPurposeController.text : null;
        editedData['year'] = _selectedYear;
        editedData['spray_color'] = _selectedSprayColor;
        editedData['timestamp'] = FieldValue.serverTimestamp();

        // Interne Nummer NICHT ändern (wird nicht im editedData überschrieben)
        editedData['internal_number'] = widget.item.internalNumber;

        // Bereinige null-Werte
        editedData.removeWhere((key, value) => value == null);

        await FirebaseFirestore.instance.collection('roundwood').doc(widget.item.id).update(editedData);

        if (!mounted) return;
        AppToast.show(message: 'Änderungen erfolgreich gespeichert', height: h);
        Navigator.pop(context, {'action': 'update', 'data': editedData});
      } catch (e) {
        AppToast.show(message: 'Fehler beim Speichern: $e', height: h);
      }
    }
  }

  @override
  void dispose() {
    _originalNumberController.dispose();
    _plaketteColorController.dispose();
    _remarksController.dispose();
    _volumeController.dispose();
    _originController.dispose();
    _otherPurposeController.dispose();
    _customYearController.dispose();
    super.dispose();
  }
}