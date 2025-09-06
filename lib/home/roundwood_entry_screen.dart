import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../services/icon_helper.dart';

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

  List<QueryDocumentSnapshot>? purposes; // Für die Verwendungszwecke aus der DB
  List<String> selectedPurposes = []; // Für die ausgewählten Verwendungszwecke

  // Controllers
  final TextEditingController _internalNumberController = TextEditingController();
  final TextEditingController _originalNumberController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _volumeController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _originController = TextEditingController();
  // Selections
  DateTime? _selectedDate;
  bool _isMoonwood = false;
  bool _isFSC = false;
  String? _selectedWoodType;
  String? _selectedQuality;
  String? _selectedColor;
  String? _selectedOrigin;

  // Dropdown data
  List<QueryDocumentSnapshot>? woodTypes;
  List<QueryDocumentSnapshot>? qualities;
  List<QueryDocumentSnapshot>? origins;
  final List<String> _colors = ['ohne', 'rot', 'blau', 'grün', 'gelb'];

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
  // Laden der letzten internen Nummer
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
            // Nur bei neuem Eintrag die nächste Nummer vorschlagen
            _internalNumberController.text =
                (int.parse(_lastInternalNumber!) + 1).toString().padLeft(3, '0');
          }
        });
      } else {
        // Wenn noch keine Nummer existiert, mit 001 beginnen
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

  // Validierung der eingegebenen Nummer
  Future<void> _validateInternalNumber() async {
    if (_internalNumberController.text.isEmpty) return;

    try {
      // Prüfen ob die Nummer bereits existiert
      final querySnapshot = await FirebaseFirestore.instance
          .collection('roundwood')
          .where('internal_number', isEqualTo: _internalNumberController.text.padLeft(3, '0'))
          .get();

      setState(() {
        _isNumberTaken = querySnapshot.docs.isNotEmpty;
        // Im Bearbeitungsmodus ist die eigene Nummer erlaubt
        if (widget.editMode && widget.roundwoodData != null) {
          _isNumberTaken = _isNumberTaken &&
              querySnapshot.docs.first.id != widget.documentId;
        }
      });
    } catch (e) {
      print('Fehler bei der Nummernvalidierung: $e');
    }
  }

  // Überschreibe das TextFormField für die interne Nummer
  Widget _buildInternalNumberField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
               getAdaptiveIcon(iconName: 'info', defaultIcon:Icons.info, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Jahrgang: ${DateTime.now().year}',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _internalNumberController,
          decoration: _getInputDecoration(
            labelText: 'Interne Nummer',
            icon: Icons.tag,
            helperText: 'Letzte verwendete Nummer: ${_lastInternalNumber ?? "keine"}',
          ).copyWith(
            errorText: _isNumberTaken ? 'Diese Nummer ist bereits vergeben!' : null,
            errorStyle: const TextStyle(
              color: Colors.red,
              fontSize: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _isNumberTaken ? Colors.red : Colors.grey[400]!,
                width: _isNumberTaken ? 2 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _isNumberTaken ? Colors.red : const Color(0xFF0F4A29),
                width: 2,
              ),
            ),
          ),
          maxLength: 3,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Pflichtfeld';
            if (_isNumberTaken) return 'Nummer bereits vergeben';
            return null;
          },
        ),
      ],
    );
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

      final purposesSnapshot = await FirebaseFirestore.instance
          .collection('instruments') // Annahme: Die Verwendungszwecke sind in der parts Collection
          .orderBy('code')
          .get();

      if (!mounted) return;

      setState(() {
        woodTypes = woodTypesSnapshot.docs;
        qualities = qualitiesSnapshot.docs;
        purposes = purposesSnapshot.docs;

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
    _isMoonwood = data['is_moonwood'] ?? false;
    _isFSC = data['is_fsc'] ?? false;  // NEU
    _volumeController.text = data['volume']?.toString() ?? '';
    _remarksController.text = data['remarks'] ?? '';
    _originController.text = data['origin'] ?? '';
    _isMoonwood = data['is_moonwood'] ?? false;
    _selectedWoodType = data['wood_type'];
    _selectedQuality = data['quality'];
    _selectedColor = data['color'];
    _selectedDate = data['cutting_date']?.toDate();
    selectedPurposes = List<String>.from(data['purpose_codes'] ?? []);
    _purposeController.text = data['additional_purpose'] ?? '';
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
              _buildPropertiesCard(),
              const SizedBox(height: 16),
              _buildAdditionalInformationCard(),
              const SizedBox(height: 24),
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveRoundwood,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F4A29),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    widget.editMode ? 'Änderungen speichern' : 'Speichern',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    // Mapping von IconData zu String-Namen
    if (icon == Icons.tag) return 'tag';
    if (icon == Icons.forest) return 'forest';
    if (icon == Icons.assignment) return 'assignment';
    if (icon == Icons.straighten) return 'straighten';
    if (icon == Icons.star) return 'star';
    if (icon == Icons.note_add) return 'note_add';
    if (icon == Icons.calendar_today) return 'calendar_today';
    if (icon == Icons.color_lens) return 'color_lens';
    if (icon == Icons.location_on) return 'location_on';
    if (icon == Icons.add) return 'add';

    // Standardwert für unbekannte Icons
    return 'circle';
  }
// Neue Methode für den Auswahl-Dialog
  void _showPurposeSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F4A29).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:getAdaptiveIcon(
                      iconName: 'assignment',
                      defaultIcon: Icons.assignment,
                      color: const Color(0xFF0F4A29),
                    )
                  ),
                  const SizedBox(width: 8),
                  const Text('Verwendungszwecke',style: smallestHeadline,),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (purposes != null)
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: purposes!.length,
                          itemBuilder: (context, index) {
                            final data = purposes![index].data() as Map<String, dynamic>;
                            final code = data['code'] as String;
                            final name = data['name'] as String;

                            return CheckboxListTile(
                              title: Text(name),
                              subtitle: Text('Code: $code'),
                              value: selectedPurposes.contains(code),
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    selectedPurposes.add(code);
                                  } else {
                                    selectedPurposes.remove(code);
                                  }
                                });
                              },
                              activeColor: const Color(0xFF0F4A29),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Abbrechen'),
                ),
                ElevatedButton(
                  onPressed: () {
                    this.setState(() {}); // Update parent state
                    Navigator.of(context).pop();
                  },
                  child: const Text('Auswählen'),
                ),
              ],
            );
          },
        );
      },
    );
  }

// Das eigentliche Eingabefeld
  Widget _buildPurposeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Auswahlfeld für vordefinierte Verwendungszwecke
        InkWell(
          onTap: _showPurposeSelectionDialog,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[400]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[100],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    getAdaptiveIcon(
                      iconName: 'assignment',
                      defaultIcon: Icons.assignment,
                      color: const Color(0xFF0F4A29),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Verwendungszwecke',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    getAdaptiveIcon(
                      iconName: 'arrow_drop_down',
                      defaultIcon: Icons.arrow_drop_down,
                      color: Colors.grey[600],
                    )
                  ],
                ),
                if (selectedPurposes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selectedPurposes.map((code) {
                      final name = getNameFromDocs(purposes!, code);
                      return Chip(
                        label: Text(name),
                        deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
                        onDeleted: () {
                          setState(() {
                            selectedPurposes.remove(code);
                          });
                        },
                        backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
                        labelStyle: const TextStyle(color: Color(0xFF0F4A29)),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Freitextfeld für zusätzliche Verwendungszwecke
        TextFormField(
          controller: _purposeController,
          decoration: _getInputDecoration(
            labelText: 'Weitere Verwendungszwecke',
            icon: Icons.add,
            helperText: 'Zusätzliche Verwendungszwecke hier eingeben',
          ),
          maxLines: 2,
        ),
      ],
    );
  }

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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F4A29).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      getAdaptiveIcon(
                        iconName: 'format_list_numbered',
                        defaultIcon: Icons.format_list_numbered,
                        color: const Color(0xFF0F4A29),

                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Grundinformationen',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F4A29),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildInternalNumberField(),
            const SizedBox(height: 16),
            TextFormField(
              controller: _originalNumberController,
              decoration: _getInputDecoration(
                labelText: 'Original Stammnummer',
                icon: Icons.tag,
              ),

              maxLength: 5,
              validator: (value) => value?.isEmpty ?? true ? 'Pflichtfeld' : null,
            ),
            const SizedBox(height: 16),
            if (woodTypes != null)
              DropdownButtonFormField<String>(
                decoration: _getInputDecoration(
                  labelText: 'Holzart',
                  icon: Icons.forest,
                ),
                value: _selectedWoodType,
                items: woodTypes!.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return DropdownMenuItem<String>(
                    value: data['code'] as String,
                    child: Text(
                      '${data['name']} (${data['code']})',
                      style: const TextStyle(color: Colors.black87),
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedWoodType = value),
                validator: (value) => value == null ? 'Pflichtfeld' : null,
              )
          ],
        ),
      ),
    );
  }

  Widget _buildPropertiesCard() {
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F4A29).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: getAdaptiveIcon(
                    iconName: 'approval',
                    defaultIcon: Icons.approval,
                    color: const Color(0xFF0F4A29),
                  )
                ),
                const SizedBox(width: 12),
                const Text(
                  'Eigenschaften',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F4A29),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildPurposeSection(),

            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[400]!),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[100],
              ),
              child: SwitchListTile(
                title: const Text(
                  'Mondholz',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                value: _isMoonwood,
                onChanged: (value) => setState(() => _isMoonwood = value),
                secondary: getAdaptiveIcon(
                  iconName: 'nightlight',
                  defaultIcon: Icons.nightlight,
                  color: const Color(0xFF0F4A29),
                )
              ),
            ),
            const SizedBox(height: 16),


            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[400]!),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[100],
              ),
              child: SwitchListTile(
                  title: const Text(
                    'FSC',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  value: _isFSC,
                  onChanged: (value) => setState(() => _isFSC = value),
                  secondary: getAdaptiveIcon(
                    iconName: 'eco',
                    defaultIcon: Icons.eco,
                    color: const Color(0xFF0F4A29),
                  )
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _volumeController,
    decoration: _getInputDecoration(
    labelText: 'Volumen (m³)',
    icon: Icons.straighten,
    )
             ,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F4A29).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:getAdaptiveIcon(
                    iconName: 'more_horiz',
                    defaultIcon: Icons.more_horiz,
                    color: const Color(0xFF0F4A29),
                  )
                ),
                const SizedBox(width: 12),
                const Text(
                  'Weitere Informationen',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F4A29),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (qualities != null)
              DropdownButtonFormField<String>(
                decoration: _getInputDecoration(
                  labelText: 'Qualität',
                  icon: Icons.star,
                ),
                value: _selectedQuality,
                items: qualities!.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return DropdownMenuItem<String>(
                    value: data['code'] as String,
                    child: Text('${data['name']} (${data['code']})'),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedQuality = value),
                validator: (value) => value == null ? 'Pflichtfeld' : null,
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _remarksController,
              decoration: _getInputDecoration(
                labelText: 'Bemerkungen',
                icon: Icons.note_add,
              ),

              maxLines: 3,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _selectDate(context),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[100],
                ),
                child: ListTile(
                  leading:
                  getAdaptiveIcon(iconName: 'calendar_today', defaultIcon: Icons.calendar_today,
                    color: Color(0xFF0F4A29),
                  ),
                  title: Text(
                    _selectedDate == null
                        ? 'Kein Datum ausgewählt'
                        : DateFormat('dd.MM.yyyy').format(_selectedDate!),
                    style: TextStyle(
                      color: _selectedDate == null ? Colors.grey[600] : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    'Einschnitt Datum',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  onTap: () => _selectDate(context),
                  trailing:  getAdaptiveIcon(iconName: 'arrow_drop_down',defaultIcon:Icons.arrow_drop_down, color: Colors.grey[600]),
                ),
              )
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: _getInputDecoration(
                labelText: 'Farbe',
                icon: Icons.color_lens,
              ),

              value: _selectedColor,
              items: _colors.map((color) => DropdownMenuItem<String>(
                value: color,
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: _getColorFromString(color),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                    ),
                    Text(color),
                  ],
                ),
              )).toList(),
              onChanged: (value) => setState(() => _selectedColor = value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _originController,
              decoration: _getInputDecoration(
    labelText: 'Herkunft / Holzschlag',
    icon: Icons.location_on,
            ),)
          ],
        ),
      ),
    );
  }

// Hilfsfunktion für die Farbauswahl
  Color _getColorFromString(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'rot':
        return Colors.red[200]!;
      case 'blau':
        return Colors.blue[200]!;
      case 'grün':
        return Colors.green[200]!;
      case 'gelb':
        return Colors.yellow[200]!;
      default:
        return Colors.grey[100]!;
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
      AppToast.show(
          message: 'Die interne Nummer ${_internalNumberController.text} ist bereits vergeben!',
          height: h
      );
      return;
    }
    if (_formKey.currentState!.validate()) {
      try {
        final roundwoodData = {

          'is_fsc': _isFSC,  // NEU
          'internal_number': _internalNumberController.text,
          'original_number': _originalNumberController.text,
          'wood_type': _selectedWoodType,
          'wood_name': getNameFromDocs(woodTypes!, _selectedWoodType!),
          'purpose_codes': selectedPurposes, // Die ausgewählten Codes
          'purpose_names': selectedPurposes.map((code) =>
              getNameFromDocs(purposes!, code)).toList(), // Die zugehörigen Namen
          'additional_purpose': _purposeController.text, // Zusätzlicher Freitext

          'is_moonwood': _isMoonwood,
          'volume': _volumeController.text.isNotEmpty
              ? double.parse(_volumeController.text.replaceAll(',', '.'))
              : null,
          'quality': _selectedQuality,
          'quality_name': _selectedQuality != null
              ? getNameFromDocs(qualities!, _selectedQuality!)
              : null,
          'remarks': _remarksController.text,
          'cutting_date': _selectedDate,
          'color': _selectedColor,
          'origin': _originController.text,
          'year': DateTime.now().year,
          'timestamp': FieldValue.serverTimestamp(),
        };

        if (widget.editMode && widget.documentId != null) {
          await FirebaseFirestore.instance
              .collection('roundwood')
              .doc(widget.documentId)
              .update(roundwoodData);
        } else {
          await FirebaseFirestore.instance
              .collection('roundwood')
              .add(roundwoodData);

          // Aktualisiere die letzte verwendete Nummer
          await FirebaseFirestore.instance
              .collection('general_data')
              .doc('roundwood')
              .set({
            'last_internal_number': _internalNumberController.text,
            'last_updated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

        }

        if (!mounted) return;
        Navigator.pop(context);
        AppToast.show(message:'Rundholz erfolgreich gespeichert', height: h);


      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String getNameFromDocs(List<QueryDocumentSnapshot> docs, String code) {
    try {
      final doc = docs.firstWhere(
            (doc) => (doc.data() as Map<String, dynamic>)['code'] == code,
      );
      return (doc.data() as Map<String, dynamic>)['name'] as String;
    } catch (e) {
      print('Fehler beim Abrufen des Namens für Code $code: $e');
      return '';
    }
  }

  @override
  void dispose() {
    _internalNumberController.dispose();
    _originalNumberController.dispose();
    _purposeController.dispose();
    _volumeController.dispose();
    _remarksController.dispose();
    _originController.dispose();

    _internalNumberController.removeListener(_validateInternalNumber);
    super.dispose();
  }
}