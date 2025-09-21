import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/icon_helper.dart';

class StandardizedPackagesScreen extends StatefulWidget {
  const StandardizedPackagesScreen({Key? key}) : super(key: key);

  @override
  State<StandardizedPackagesScreen> createState() => _StandardizedPackagesScreenState();
}

class _StandardizedPackagesScreenState extends State<StandardizedPackagesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Standardpakete'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('standardized_packages')
            .orderBy('name')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Fehler: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final packages = snapshot.data?.docs ?? [];

          if (packages.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  getAdaptiveIcon(
                    iconName: 'inventory',
                    defaultIcon: Icons.inventory,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Keine Standardpakete vorhanden',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Erstelle dein Ihr erstes Standardpaket',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: packages.length,
            itemBuilder: (context, index) {
              final package = packages[index];
              final data = package.data() as Map<String, dynamic>;

              return _buildPackageCard(package.id, data);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPackageDialog(null, null),
        child:  getAdaptiveIcon(
            iconName: 'add',
            defaultIcon:Icons.add),
        tooltip: 'Neues Standardpaket',
      ),
    );
  }

  Widget _buildPackageCard(String packageId, Map<String, dynamic> data) {
    final length = data['length'] ?? 0.0;
    final width = data['width'] ?? 0.0;
    final height = data['height'] ?? 0.0;
    final weight = data['weight'] ?? 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child:  getAdaptiveIcon(
            iconName: 'inventory',
            defaultIcon: Icons.inventory,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          data['name'] ?? 'Unbenannt',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                getAdaptiveIcon(
                    iconName: 'straighten',
                    defaultIcon:Icons.straighten, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${length.toStringAsFixed(1)} × ${width.toStringAsFixed(1)} × ${height.toStringAsFixed(1)} cm',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                getAdaptiveIcon(
                    iconName: 'scale',
                    defaultIcon:Icons.scale, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${weight.toStringAsFixed(2)} kg',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),

          ],
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon:  getAdaptiveIcon(
                  iconName: 'edit',
                  defaultIcon:Icons.edit, size: 20),
              onPressed: () => _showPackageDialog(packageId, data),
              tooltip: 'Bearbeiten',
            ),
            IconButton(
              icon:  getAdaptiveIcon(
                  iconName: 'delete',
                  defaultIcon:Icons.delete, size: 20, color: Colors.red),
              onPressed: () => _showDeleteConfirmation(packageId, data['name']),
              tooltip: 'Löschen',
            ),
          ],
        ),
      ),
    );
  }

  void _showPackageDialog(String? packageId, Map<String, dynamic>? packageData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: PackageDialog(
          packageId: packageId,
          packageData: packageData,
          onSave: () => setState(() {}), // Refresh nach Speichern
        ),
      ),
    );
  }

  void _showDeleteConfirmation(String packageId, String packageName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paket löschen'),
        content: Text('Möchtest du das Paket "$packageName" wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('standardized_packages')
                    .doc(packageId)
                    .delete();

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Paket wurde gelöscht'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Fehler beim Löschen: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }
}

// Dialog zum Erstellen/Bearbeiten von Paketen
class PackageDialog extends StatefulWidget {
  final String? packageId;
  final Map<String, dynamic>? packageData;
  final VoidCallback onSave;

  const PackageDialog({
    Key? key,
    this.packageId,
    this.packageData,
    required this.onSave,
  }) : super(key: key);

  @override
  State<PackageDialog> createState() => _PackageDialogState();
}

class _PackageDialogState extends State<PackageDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _lengthController;
  late TextEditingController _widthController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _descriptionController;
  late TextEditingController _nameEnController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.packageData?['name'] ?? '');
    _lengthController = TextEditingController(
      text: widget.packageData?['length']?.toString() ?? '',
    );
    _widthController = TextEditingController(
      text: widget.packageData?['width']?.toString() ?? '',
    );
    _heightController = TextEditingController(
      text: widget.packageData?['height']?.toString() ?? '',
    );
    _weightController = TextEditingController(
      text: widget.packageData?['weight']?.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.packageData?['description'] ?? '',
    );
    _nameEnController = TextEditingController(text: widget.packageData?['nameEn'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _descriptionController.dispose();
    _nameEnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Drag Handle
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child:  getAdaptiveIcon(
                  iconName: 'inventory',
                  defaultIcon:
                  Icons.inventory,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                widget.packageId == null ? 'Neues Standardpaket' : 'Paket bearbeiten',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon:  getAdaptiveIcon(
                    iconName: 'close',
                    defaultIcon:Icons.close),
              ),
            ],
          ),
        ),

        const Divider(),

        // Form
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Paketname *',
                      hintText: 'z.B. Kartonschachtel Klein',
                      prefixIcon:  getAdaptiveIcon(
                          iconName:  'label',
                          defaultIcon:Icons.label),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Bitte Namen eingeben';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

// Englischer Name
                  TextFormField(
                    controller: _nameEnController,
                    decoration: InputDecoration(
                      labelText: 'Package name (English) *',
                      hintText: 'e.g. Small Cardboard Box',
                      prefixIcon:  getAdaptiveIcon(
                          iconName: 'translate',
                          defaultIcon:Icons.translate),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter English name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Beschreibung
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Beschreibung (optional)',
                      hintText: 'z.B. Für kleine Bauteile',
                      prefixIcon:  getAdaptiveIcon(
                          iconName: 'description',
                          defaultIcon:Icons.description),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    maxLines: 2,
                  ),

                  const SizedBox(height: 24),

                  // Abmessungen
                  Text(
                    'Abmessungen',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _lengthController,
                          decoration: InputDecoration(
                            labelText: 'Länge (cm) *',
                            prefixIcon:  getAdaptiveIcon(
                                iconName: 'straighten',
                                defaultIcon:Icons.straighten),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Erforderlich';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Ungültige Zahl';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('×', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _widthController,
                          decoration: InputDecoration(
                            labelText: 'Breite (cm) *',
                            prefixIcon:  getAdaptiveIcon(
                                iconName: 'swap_horiz',
                                defaultIcon:Icons.swap_horiz),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Erforderlich';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Ungültige Zahl';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('×', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _heightController,
                          decoration: InputDecoration(
                            labelText: 'Höhe (cm) *',
                            prefixIcon: getAdaptiveIcon(
                                iconName: 'height',
                                defaultIcon:Icons.height),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Erforderlich';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Ungültige Zahl';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Gewicht
                  Text(
                    'Gewicht',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _weightController,
                    decoration: InputDecoration(
                      labelText: 'Leergewicht (kg) *',
                      hintText: 'Gewicht der leeren Verpackung',
                      prefixIcon:  getAdaptiveIcon(
                          iconName: 'scale',
                          defaultIcon:Icons.scale),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Bitte Gewicht eingeben';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Ungültige Zahl';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 32),

                  // Volumen-Anzeige (berechnet)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        getAdaptiveIcon(
                          iconName: 'square_foot',
                          defaultIcon:
                          Icons.square_foot,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Volumen',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              Text(
                                _calculateVolume(),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Actions
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
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
                  onPressed: _save,
                  icon: getAdaptiveIcon(
                      iconName: 'save',
                      defaultIcon:Icons.save),
                  label: const Text('Speichern'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _calculateVolume() {
    final length = double.tryParse(_lengthController.text) ?? 0;
    final width = double.tryParse(_widthController.text) ?? 0;
    final height = double.tryParse(_heightController.text) ?? 0;

    final volumeCm3 = length * width * height;
    final volumeM3 = volumeCm3 / 1000000;

    if (volumeCm3 == 0) {
      return 'Wird berechnet...';
    }

    return '${volumeCm3.toStringAsFixed(0)} cm³ (${volumeM3.toStringAsFixed(4)} m³)';
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      try {
        final data = {
          'name': _nameController.text.trim(),
          'nameEn': _nameEnController.text.trim(),
          'description': _descriptionController.text.trim(),
          'length': double.parse(_lengthController.text),
          'width': double.parse(_widthController.text),
          'height': double.parse(_heightController.text),
          'weight': double.parse(_weightController.text),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (widget.packageId == null) {
          // Neues Paket
          data['createdAt'] = FieldValue.serverTimestamp();
          await FirebaseFirestore.instance
              .collection('standardized_packages')
              .add(data);
        } else {
          // Bestehendes Paket aktualisieren
          await FirebaseFirestore.instance
              .collection('standardized_packages')
              .doc(widget.packageId)
              .update(data);
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.packageId == null
                    ? 'Standardpaket wurde erstellt'
                    : 'Standardpaket wurde aktualisiert',
              ),
              backgroundColor: Colors.green,
            ),
          );
          widget.onSave();
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
      }
    }
  }
}