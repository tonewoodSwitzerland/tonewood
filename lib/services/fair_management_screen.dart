import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'fairs.dart';
import 'icon_helper.dart';

// Screen zur Verwaltung der Messen
class FairManagementScreen extends StatefulWidget {
  const FairManagementScreen({Key? key}) : super(key: key);

  @override
  FairManagementScreenState createState() => FairManagementScreenState();
}

class FairManagementScreenState extends State<FairManagementScreen> {
  final TextEditingController searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messeverwaltung'),
        actions: [
          IconButton(
            icon: getAdaptiveIcon(iconName: 'add', defaultIcon: Icons.add),
            onPressed: () => _showFairSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Messe suchen',
                prefixIcon: getAdaptiveIcon(iconName: 'search', defaultIcon: Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon:  getAdaptiveIcon(iconName: 'clear', defaultIcon:Icons.clear),
                  onPressed: () {
                    searchController.clear();
                    setState(() {});
                  },
                ),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('fairs')
                  .orderBy('startDate', descending: true)
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

                final fairs = snapshot.data?.docs ?? [];
                final searchTerm = searchController.text.toLowerCase();

                final filteredFairs = fairs.where((doc) {
                  final fair = Fair.fromMap(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  );
                  return fair.name.toLowerCase().contains(searchTerm) ||
                      fair.location.toLowerCase().contains(searchTerm) ||
                      fair.city.toLowerCase().contains(searchTerm);
                }).toList();

                if (filteredFairs.isEmpty) {
                  return const Center(
                    child: Text('Keine Messen gefunden'),
                  );
                }

                return ListView.builder(
                  itemCount: filteredFairs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredFairs[index];
                    final fair = Fair.fromMap(
                      doc.data() as Map<String, dynamic>,
                      doc.id,
                    );

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        title: Text(fair.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${fair.city}, ${fair.country}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Datum: ${DateFormat('dd.MM.yyyy').format(fair.startDate)} - '
                                  '${DateFormat('dd.MM.yyyy').format(fair.endDate)}',
                            ),
                            Text('Kostenstelle: ${fair.costCenterCode}'),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: getAdaptiveIcon(iconName: 'edit',defaultIcon:Icons.edit),
                              onPressed: () => _showFairSheet(context, fair: fair),
                            ),
                            IconButton(
                              icon: getAdaptiveIcon(iconName: 'delete', defaultIcon: Icons.delete),
                              onPressed: () => _showDeleteFairDialog(fair),
                            ),
                          ],
                        ),
                        onTap: () => _showFairDetailsSheet(context, fair),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showFairSheet(BuildContext context, {Fair? fair}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FairFormSheet(fair: fair),
    );
  }

  void _showFairDetailsSheet(BuildContext context, Fair fair) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FairDetailsSheet(
        fair: fair,
        onEdit: () {
          Navigator.pop(context);
          _showFairSheet(context, fair: fair);
        },
      ),
    );
  }

  void _showDeleteFairDialog(Fair fair) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Messe löschen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Möchtest du die folgende Messe wirklich löschen?',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Name', fair.name),
            _buildDetailRow('Ort', '${fair.city}, ${fair.country}'),
            _buildDetailRow('Datum',
                '${DateFormat('dd.MM.yyyy').format(fair.startDate)} - '
                    '${DateFormat('dd.MM.yyyy').format(fair.endDate)}'
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('fairs')
                    .doc(fair.id)
                    .delete();

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Messe erfolgreich gelöscht'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Fehler beim Löschen: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            icon: getAdaptiveIcon(iconName: 'delete', defaultIcon: Icons.delete),
            label: const Text('Löschen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}

// Modal Sheet für Formular (Neu/Bearbeiten)
class FairFormSheet extends StatefulWidget {
  final Fair? fair;

  const FairFormSheet({Key? key, this.fair}) : super(key: key);

  @override
  State<FairFormSheet> createState() => _FairFormSheetState();
}

class _FairFormSheetState extends State<FairFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController locationController;
  late final TextEditingController costCenterController;
  late final TextEditingController startDateController;
  late final TextEditingController endDateController;
  late final TextEditingController countryController;
  late final TextEditingController cityController;
  late final TextEditingController addressController;
  late final TextEditingController notesController;

  DateTime? selectedStartDate;
  DateTime? selectedEndDate;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.fair?.name ?? '');
    locationController = TextEditingController(text: widget.fair?.location ?? '');
    costCenterController = TextEditingController(text: widget.fair?.costCenterCode ?? '');
    startDateController = TextEditingController(
      text: widget.fair != null ? DateFormat('dd.MM.yyyy').format(widget.fair!.startDate) : '',
    );
    endDateController = TextEditingController(
      text: widget.fair != null ? DateFormat('dd.MM.yyyy').format(widget.fair!.endDate) : '',
    );
    countryController = TextEditingController(text: widget.fair?.country ?? 'Schweiz');
    cityController = TextEditingController(text: widget.fair?.city ?? '');
    addressController = TextEditingController(text: widget.fair?.address ?? '');
    notesController = TextEditingController(text: widget.fair?.notes ?? '');

    selectedStartDate = widget.fair?.startDate;
    selectedEndDate = widget.fair?.endDate;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.fair != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            margin: EdgeInsets.only(top: 12, bottom: 8),
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
                getAdaptiveIcon(
                  iconName: isEdit ? 'edit' : 'add_circle',
                  defaultIcon: isEdit ? Icons.edit : Icons.add_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  isEdit ? 'Messe bearbeiten' : 'Neue Messe',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Divider(height: 1),

          // Scrollbarer Inhalt
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Allgemeine Informationen
                    _buildSectionTitle('Allgemeine Informationen', Icons.info),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Messebezeichnung *',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        prefixIcon: getAdaptiveIcon(
                          iconName: 'event',
                          defaultIcon: Icons.event,
                        ),
                      ),
                      validator: (value) =>
                      value?.isEmpty == true ? 'Bitte Bezeichnung eingeben' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: costCenterController,
                      decoration: InputDecoration(
                        labelText: isEdit ? 'Kostenstelle' : 'Kostenstelle *',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        prefixIcon: getAdaptiveIcon(
                          iconName: 'account_balance_wallet',
                          defaultIcon: Icons.account_balance_wallet,
                        ),
                      ),
                      validator: isEdit ? null : (value) =>
                      value?.isEmpty == true ? 'Bitte Kostenstelle eingeben' : null,
                    ),

                    const SizedBox(height: 24),

                    // Zeitraum
                    _buildSectionTitle('Zeitraum', Icons.date_range),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: startDateController,
                            decoration: InputDecoration(
                              labelText: 'Startdatum *',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              prefixIcon: getAdaptiveIcon(
                                iconName: 'calendar_today',
                                defaultIcon: Icons.calendar_today,
                              ),
                            ),
                            readOnly: true,
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: selectedStartDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (date != null) {
                                setState(() {
                                  selectedStartDate = date;
                                  startDateController.text =
                                      DateFormat('dd.MM.yyyy').format(date);
                                });
                              }
                            },
                            validator: (value) =>
                            value?.isEmpty == true ? 'Bitte Startdatum wählen' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: endDateController,
                            decoration: InputDecoration(
                              labelText: 'Enddatum *',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              prefixIcon: getAdaptiveIcon(
                                iconName: 'calendar_today',
                                defaultIcon: Icons.calendar_today,
                              ),
                            ),
                            readOnly: true,
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: selectedEndDate ?? selectedStartDate ?? DateTime.now(),
                                firstDate: selectedStartDate ?? DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (date != null) {
                                setState(() {
                                  selectedEndDate = date;
                                  endDateController.text =
                                      DateFormat('dd.MM.yyyy').format(date);
                                });
                              }
                            },
                            validator: (value) =>
                            value?.isEmpty == true ? 'Bitte Enddatum wählen' : null,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Veranstaltungsort
                    _buildSectionTitle('Veranstaltungsort', Icons.location_on),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: addressController,
                      decoration: InputDecoration(
                        labelText: 'Adresse ',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        prefixIcon: getAdaptiveIcon(
                          iconName: 'home',
                          defaultIcon: Icons.home,
                        ),
                      ),

                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: cityController,
                            decoration: InputDecoration(
                              labelText: 'Stadt ',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              prefixIcon: getAdaptiveIcon(
                                iconName: 'location_city',
                                defaultIcon: Icons.location_city,
                              ),
                            ),

                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: countryController,
                            decoration: InputDecoration(
                              labelText: 'Land ',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              prefixIcon: getAdaptiveIcon(
                                iconName: 'public',
                                defaultIcon: Icons.public,
                              ),
                            ),

                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Zusätzliche Informationen
                    _buildSectionTitle('Zusätzliche Informationen', Icons.notes),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: notesController,
                      decoration: InputDecoration(
                        labelText: 'Notizen',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        prefixIcon: getAdaptiveIcon(
                          iconName: 'note',
                          defaultIcon: Icons.note,
                        ),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),

                    const SizedBox(height: 16),

                    // Pflichtfeld-Hinweis
                    Text(
                      '* Pflichtfelder',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Footer mit Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Abbrechen'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveFair,
                      icon: getAdaptiveIcon(
                        iconName: 'save',
                        defaultIcon: Icons.save,
                        color: Colors.white,
                      ),
                      label: const Text('Speichern'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        getAdaptiveIcon(
          iconName: icon.toString().split('.').last,
          defaultIcon: icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  void _saveFair() async {
    if (_formKey.currentState?.validate() == true &&
        selectedStartDate != null &&
        selectedEndDate != null) {
      final fair = Fair(
        id: widget.fair?.id ?? '',
        name: nameController.text,
        location: locationController.text,
        costCenterCode: costCenterController.text,
        startDate: selectedStartDate!,
        endDate: selectedEndDate!,
        country: countryController.text,
        city: cityController.text,
        address: addressController.text,
        notes: notesController.text,
      );

      try {
        if (widget.fair == null) {
          await FirebaseFirestore.instance
              .collection('fairs')
              .add(fair.toMap());
        } else {
          await FirebaseFirestore.instance
              .collection('fairs')
              .doc(fair.id)
              .update(fair.toMap());
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.fair == null
                  ? 'Messe erfolgreich angelegt'
                  : 'Messe erfolgreich aktualisiert'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    locationController.dispose();
    costCenterController.dispose();
    startDateController.dispose();
    endDateController.dispose();
    countryController.dispose();
    cityController.dispose();
    addressController.dispose();
    notesController.dispose();
    super.dispose();
  }
}

// Modal Sheet für Details
class FairDetailsSheet extends StatelessWidget {
  final Fair fair;
  final VoidCallback onEdit;

  const FairDetailsSheet({
    Key? key,
    required this.fair,
    required this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            margin: EdgeInsets.only(top: 12, bottom: 8),
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
                getAdaptiveIcon(
                  iconName: 'event',
                  defaultIcon: Icons.event,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    fair.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Divider(height: 1),

          // Scrollbarer Inhalt
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Zeitraum Card
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              getAdaptiveIcon(
                                iconName: 'date_range',
                                defaultIcon: Icons.date_range,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Zeitraum',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${DateFormat('dd.MM.yyyy').format(fair.startDate)} - '
                                '${DateFormat('dd.MM.yyyy').format(fair.endDate)}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Kostenstelle Card
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              getAdaptiveIcon(
                                iconName: 'account_balance_wallet',
                                defaultIcon: Icons.account_balance_wallet,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Kostenstelle',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            fair.costCenterCode,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Veranstaltungsort Card
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              getAdaptiveIcon(
                                iconName: 'location_on',
                                defaultIcon: Icons.location_on,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Veranstaltungsort',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            fair.address,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${fair.city}, ${fair.country}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (fair.notes?.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    // Notizen Card
                    Card(
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                getAdaptiveIcon(
                                  iconName: 'notes',
                                  defaultIcon: Icons.notes,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Notizen',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              fair.notes!,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Footer mit Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Schließen'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onEdit,
                      icon: getAdaptiveIcon(iconName: 'edit',defaultIcon:Icons.edit, color: Colors.white),
                      label: const Text('Bearbeiten'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}