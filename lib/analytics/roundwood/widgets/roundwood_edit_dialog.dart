import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../constants.dart';
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
  List<QueryDocumentSnapshot>? purposes;
  List<String> selectedPurposes = [];

  @override
  void initState() {
    super.initState();
    editedData = widget.item.toMap();
    selectedPurposes = List<String>.from(editedData['purpose_codes'] ?? []);
    _loadPurposes();
  }

  Future<void> _loadPurposes() async {
    try {
      final purposesSnapshot = await FirebaseFirestore.instance
          .collection('instruments')
          .orderBy('code')
          .get();

      if (mounted) {
        setState(() {
          purposes = purposesSnapshot.docs;
        });
      }
    } catch (e) {
      print('Fehler beim Laden der Verwendungszwecke: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxWidth: widget.isDesktopLayout ? 800 : 600,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F4A29).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.forest,
                      color: Color(0xFF0F4A29),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rundholz ${widget.item.internalNumber}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F4A29),
                          ),
                        ),
                        if (widget.item.woodName != null)
                          Text(
                            widget.item.woodName!,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Identifikation Section
                      _buildDetailSection(
                        title: 'Identifikation',
                        icon: Icons.badge,
                        content: Column(
                          children: [
                            _buildNumberInfo(),
                            const SizedBox(height: 16),
                            _buildWoodTypeSelection(),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Eigenschaften Section
                      _buildDetailSection(
                        title: 'Eigenschaften',
                        icon: Icons.category,
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPurposeSection(),
                            const SizedBox(height: 16),
                            _buildMoonwoodSwitch(),
                            const SizedBox(height: 16),
                            _buildVolumeInput(),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Zusätzliche Informationen Section
                      _buildDetailSection(
                        title: 'Zusätzliche Informationen',
                        icon: Icons.info_outline,
                        content: Column(
                          children: [
                            _buildQualitySelection(),
                            const SizedBox(height: 16),
                            _buildDatePicker(),
                            const SizedBox(height: 16),
                            _buildColorSelection(),
                            const SizedBox(height: 16),
                            _buildRemarksInput(),
                          ],
                        ),
                      ),
                      Center(
                        child: TextButton.icon(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          label: const Text('Löschen'),
                          onPressed: _confirmDelete,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),

              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
               mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: const Text('Abbrechen'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Speichern'),
                    onPressed: _saveChanges,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F4A29),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection({
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF0F4A29)),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F4A29),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: content,
        ),
      ],
    );
  }

  Widget _buildNumberInfo() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Interne Nummer',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.item.internalNumber,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Original Nummer',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.item.originalNumber ?? 'Keine',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWoodTypeSelection() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('wood_types').get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }

        final woodTypes = snapshot.data!.docs;
        return DropdownButtonFormField<String>(
          value: editedData['wood_type'],
          decoration: InputDecoration(
            labelText: 'Holzart',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          items: woodTypes.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return DropdownMenuItem<String>(
              value: data['code'],
              child: Text('${data['name']} (${data['code']})'),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                editedData['wood_type'] = value;
                editedData['wood_name'] = woodTypes
                    .firstWhere((doc) => (doc.data() as Map<String, dynamic>)['code'] == value)
                    .get('name');
              });
            }
          },
        );
      },
    );
  }

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
                    child: const Icon(
                      Icons.assignment,
                      color: Color(0xFF0F4A29),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Verwendungszwecke',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F4A29),
                    ),
                  ),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F4A29),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    this.setState(() {
                      editedData['purpose_codes'] = selectedPurposes;
                      editedData['purpose_names'] = selectedPurposes
                          .map((code) => purposes!
                          .firstWhere((doc) => (doc.data() as Map<String, dynamic>)['code'] == code)
                          .get('name'))
                          .toList();
                    });
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


  Widget _buildPurposeSection() {
    if (purposes == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dropdown für Verwendungszwecke
        InkWell(
          onTap: _showPurposeSelectionDialog,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.assignment, color: Color(0xFF0F4A29)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedPurposes.isEmpty
                        ? 'Verwendungszwecke auswählen'
                        : '${selectedPurposes.length} Verwendungszwecke ausgewählt',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
              ],
            ),
          ),
        ),

        if (selectedPurposes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedPurposes.map((code) {
              // Null-Check und Fehlerbehandlung
              String name;
              try {
                name = purposes!
                    .firstWhere((doc) => (doc.data() as Map<String, dynamic>)['code'] == code)
                    .get('name');
              } catch (e) {
                name = code; // Fallback wenn Name nicht gefunden
              }
              return Chip(
                label: Text(name),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () {
                  setState(() {
                    selectedPurposes.remove(code);
                    editedData['purpose_codes'] = selectedPurposes;
                    editedData['purpose_names'] = selectedPurposes
                        .map((code) {
                      try {
                        return purposes!
                            .firstWhere((doc) => (doc.data() as Map<String, dynamic>)['code'] == code)
                            .get('name');
                      } catch (e) {
                        return code;
                      }
                    })
                        .toList();
                  });
                },
                backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
                labelStyle: const TextStyle(color: Color(0xFF0F4A29)),
              );
            }).toList(),
          ),
        ],

        const SizedBox(height: 16),
        TextFormField(
          initialValue: editedData['additional_purpose'],
          decoration: InputDecoration(
            labelText: 'Weitere Verwendungszwecke',
            hintText: 'Zusätzliche Verwendungszwecke hier eingeben',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          maxLines: 2,
          onChanged: (value) => editedData['additional_purpose'] = value,
        ),
      ],
    );
  }

  Widget _buildMoonwoodSwitch() {
    return SwitchListTile(
      title: const Text('Mondholz'),
      value: editedData['is_moonwood'] ?? false,
      onChanged: (value) {
        setState(() {
          editedData['is_moonwood'] = value;
        });
      },
      activeColor: const Color(0xFF0F4A29),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildQualitySelection() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('qualities').get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }

        final qualities = snapshot.data!.docs;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Qualität',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: editedData['quality'],
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: qualities.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return DropdownMenuItem<String>(
                  value: data['code'],
                  child: Row(
                    children: [
                      Icon(
                        Icons.star,
                        size: 16,
                        color: const Color(0xFF0F4A29),
                      ),
                      const SizedBox(width: 8),
                      Text('${data['name']} (${data['code']})'),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    editedData['quality'] = value;
                    editedData['quality_name'] = qualities
                        .firstWhere((doc) => (doc.data() as Map<String, dynamic>)['code'] == value)
                        .get('name');
                  });
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Einschnitt Datum',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: editedData['cutting_date']?.toDate() ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: Color(0xFF0F4A29),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() {
                editedData['cutting_date'] = Timestamp.fromDate(picked);
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 20, color: Color(0xFF0F4A29)),
                const SizedBox(width: 8),
                Text(
                  editedData['cutting_date'] == null
                      ? 'Datum auswählen'
                      : DateFormat('dd.MM.yyyy').format(editedData['cutting_date'].toDate()),
                  style: TextStyle(
                    color: editedData['cutting_date'] == null ? Colors.grey[600] : Colors.black,
                  ),
                ),
                const Spacer(),
                Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorSelection() {
    final colors = ['ohne', 'rot', 'blau', 'grün', 'gelb'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Farbe',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: colors.map((color) {
              final isSelected = editedData['color'] == color;
              return InkWell(
                onTap: () {
                  setState(() {
                    editedData['color'] = color;
                  });
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getColorFromString(color).withOpacity(0.2),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF0F4A29) : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _getColorFromString(color),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : null,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRemarksInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bemerkungen',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: editedData['remarks'],
          decoration: InputDecoration(
            hintText: 'Zusätzliche Informationen eingeben...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          maxLines: 3,
          onChanged: (value) => editedData['remarks'] = value,
        ),
      ],
    );
  }

  Widget _buildVolumeInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Volumen',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: editedData['volume']?.toString(),
          decoration: InputDecoration(
            hintText: 'Volumen in m³',
            suffixText: 'm³',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(
              Icons.straighten,
              color: Color(0xFF0F4A29),
            ),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Pflichtfeld';
            if (double.tryParse(value!.replaceAll(',', '.')) == null) {
              return 'Ungültige Zahl';
            }
            return null;
          },
          onChanged: (value) {
            editedData['volume'] = double.tryParse(value.replaceAll(',', '.'));
          },
        ),
      ],
    );
  }

  Color _getColorFromString(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'rot':
        return Colors.red;
      case 'blau':
        return Colors.blue;
      case 'grün':
        return Colors.green;
      case 'gelb':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }
  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.warning,
                color: Colors.red,
              ),
            ),
            const SizedBox(width: 8),
            const Text('Löschen bestätigen'),
          ],
        ),
        content: Text(
          'Möchtest du das Rundholz ${widget.item.internalNumber} wirklich löschen? '
              'Diese Aktion kann nicht rückgängig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Batch für atomare Operation
        final batch = FirebaseFirestore.instance.batch();

        // Referenz zum Rundholz-Dokument
        final roundwoodRef = FirebaseFirestore.instance
            .collection('roundwood')
            .doc(widget.item.id);

        // Lösche das Dokument
        batch.delete(roundwoodRef);

        // Führe die Batch-Operation aus
        await batch.commit();

        if (!mounted) return;

        // Zeige Erfolgs-Nachricht
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rundholz wurde gelöscht'),
            backgroundColor: Colors.green,
          ),
        );

        // Schließe Dialog und gib Lösch-Info zurück
        Navigator.pop(context, {'action': 'delete', 'id': widget.item.id});

      } catch (e) {
        // Fehlerbehandlung
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Löschen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    if (formKey.currentState?.validate() ?? false) {
      try {
        // Validiere Pflichtfelder
        if (editedData['wood_type'] == null) {
          throw 'Bitte wähle eine Holzart aus';
        }
        if (editedData['quality'] == null) {
          throw 'Bitte wähle eine Qualität aus';
        }
        if (editedData['volume'] == null || editedData['volume'] <= 0) {
          throw 'Bitte gib ein gültiges Volumen ein';
        }

        // Aktualisiere Zeitstempel
        editedData['timestamp'] = FieldValue.serverTimestamp();

        // Stelle sicher, dass alle Arrays korrekt sind
        editedData['purpose_codes'] = selectedPurposes;
        editedData['purpose_names'] = selectedPurposes.map((code) {
          try {
            return purposes!
                .firstWhere((doc) => (doc.data() as Map<String, dynamic>)['code'] == code)
                .get('name');
          } catch (e) {
            return code;
          }
        }).toList();

        // Bereinige null-Werte
        editedData.removeWhere((key, value) => value == null);

        // Firebase Update durchführen
        final roundwoodRef = FirebaseFirestore.instance
            .collection('roundwood')
            .doc(widget.item.id);

        // Batch für atomare Operation
        final batch = FirebaseFirestore.instance.batch();

        // Update des Rundholz-Dokuments
        batch.update(roundwoodRef, editedData);

        // Wenn sich die interne Nummer geändert hat, aktualisiere auch general_data
        if (editedData['internal_number'] != widget.item.internalNumber) {
          final generalDataRef = FirebaseFirestore.instance
              .collection('general_data')
              .doc('roundwood');

          batch.set(generalDataRef, {
            'last_internal_number': editedData['internal_number'],
            'last_updated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        // Führe alle Änderungen aus
        await batch.commit();

        if (!mounted) return;
        AppToast.show(message: "Änderungen erfolgreich gespeichert", height: h);


        Navigator.pop(context, {
          'action': 'update',
          'data': editedData,
        });

      } catch (e) {
        // Zeige Fehlermeldung
        AppToast.show(message: "Fehler beim Speichern. Bitte überprüfe deine Eingaben.", height: h);

      }
    }
  }
}