
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
            icon:  getAdaptiveIcon(iconName: 'add', defaultIcon: Icons.add,),
            onPressed: _showAddFairDialog,
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
                prefixIcon: getAdaptiveIcon(iconName: 'search', defaultIcon: Icons.search,),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
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
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showEditFairDialog(fair),
                            ),
                            IconButton(
                              icon: getAdaptiveIcon(iconName: 'delete', defaultIcon: Icons.delete,),
                              onPressed: () => _showDeleteFairDialog(fair),
                            ),
                          ],
                        ),
                        onTap: () => _showFairDetails(fair),
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
  void _showAddFairDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final costCenterController = TextEditingController();
    final startDateController = TextEditingController();
    final endDateController = TextEditingController();
    final countryController = TextEditingController(text: 'Schweiz');
    final cityController = TextEditingController();
    final addressController = TextEditingController();
    final notesController = TextEditingController();

    DateTime? selectedStartDate;
    DateTime? selectedEndDate;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Neue Messe',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Allgemeine Informationen
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Allgemeine Informationen',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                labelText: 'Messebezeichnung *',
                                border: OutlineInputBorder(),
                                filled: true,
                              ),
                              validator: (value) =>
                              value?.isEmpty == true ? 'Bitte Bezeichnung eingeben' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: costCenterController,
                              decoration: const InputDecoration(
                                labelText: 'Kostenstelle *',
                                border: OutlineInputBorder(),
                                filled: true,
                              ),
                              validator: (value) =>
                              value?.isEmpty == true ? 'Bitte Kostenstelle eingeben' : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Zeitraum
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Zeitraum',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: startDateController,
                                    decoration: InputDecoration(
                                      labelText: 'Startdatum *',
                                      border: const OutlineInputBorder(),
                                      filled: true,
                                      prefixIcon:
                                      getAdaptiveIcon(iconName: 'calendar_today', defaultIcon: Icons.calendar_today,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    readOnly: true,
                                    onTap: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                      if (date != null) {
                                        selectedStartDate = date;
                                        startDateController.text =
                                            DateFormat('dd.MM.yyyy').format(date);
                                      }
                                    },
                                    validator: (value) =>
                                    value?.isEmpty == true ? 'Bitte Startdatum wählen' : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: endDateController,
                                    decoration: InputDecoration(
                                      labelText: 'Enddatum *',
                                      border: const OutlineInputBorder(),
                                      filled: true,
                                      prefixIcon:  getAdaptiveIcon(iconName: 'calendar_today', defaultIcon: Icons.calendar_today,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    readOnly: true,
                                    onTap: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: selectedStartDate ?? DateTime.now(),
                                        firstDate: selectedStartDate ?? DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                      if (date != null) {
                                        selectedEndDate = date;
                                        endDateController.text =
                                            DateFormat('dd.MM.yyyy').format(date);
                                      }
                                    },
                                    validator: (value) =>
                                    value?.isEmpty == true ? 'Bitte Enddatum wählen' : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Adresse
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Veranstaltungsort',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: addressController,
                              decoration: const InputDecoration(
                                labelText: 'Adresse *',
                                border: OutlineInputBorder(),
                                filled: true,
                              ),
                              validator: (value) =>
                              value?.isEmpty == true ? 'Bitte Adresse eingeben' : null,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: cityController,
                                    decoration: const InputDecoration(
                                      labelText: 'Stadt *',
                                      border: OutlineInputBorder(),
                                      filled: true,
                                    ),
                                    validator: (value) =>
                                    value?.isEmpty == true ? 'Bitte Stadt eingeben' : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: countryController,
                                    decoration: const InputDecoration(
                                      labelText: 'Land *',
                                      border: OutlineInputBorder(),
                                      filled: true,
                                    ),
                                    validator: (value) =>
                                    value?.isEmpty == true ? 'Bitte Land eingeben' : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Notizen
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Zusätzliche Informationen',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: notesController,
                              decoration: const InputDecoration(
                                labelText: 'Notizen',
                                border: OutlineInputBorder(),
                                filled: true,
                              ),
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Pflichtfeld-Hinweis und Buttons
                    Column(
                      children: [
                        Text(
                          '* Pflichtfelder',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Abbrechen'),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: () async {
                                if (formKey.currentState?.validate() == true &&
                                    selectedStartDate != null &&
                                    selectedEndDate != null) {
                                  final newFair = Fair(
                                    id: '',
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
                                    await FirebaseFirestore.instance
                                        .collection('fairs')
                                        .add(newFair.toMap());

                                    if (mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Messe erfolgreich angelegt'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Fehler beim Anlegen: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                              icon: getAdaptiveIcon(iconName: 'save', defaultIcon: Icons.save,),
                              label: const Text('Speichern'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditFairDialog(Fair fair) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: fair.name);
    final locationController = TextEditingController(text: fair.location);
    final costCenterController = TextEditingController(text: fair.costCenterCode);
    final startDateController = TextEditingController(
      text: DateFormat('dd.MM.yyyy').format(fair.startDate),
    );
    final endDateController = TextEditingController(
      text: DateFormat('dd.MM.yyyy').format(fair.endDate),
    );
    final countryController = TextEditingController(text: fair.country);
    final cityController = TextEditingController(text: fair.city);
    final addressController = TextEditingController(text: fair.address);
    final notesController = TextEditingController(text: fair.notes ?? '');

    DateTime? selectedStartDate = fair.startDate;
    DateTime? selectedEndDate = fair.endDate;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Messe bearbeiten',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Allgemeine Informationen
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Allgemeine Informationen',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                labelText: 'Messebezeichnung *',
                                border: OutlineInputBorder(),
                                filled: true,
                              ),
                              validator: (value) =>
                              value?.isEmpty == true ? 'Bitte Bezeichnung eingeben' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: costCenterController,
                              decoration: const InputDecoration(
                                labelText: 'Kostenstelle',  // Kein * mehr, da optional
                                border: OutlineInputBorder(),
                                filled: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Zeitraum
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Zeitraum',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: startDateController,
                                    decoration: InputDecoration(
                                      labelText: 'Startdatum *',
                                      border: const OutlineInputBorder(),
                                      filled: true,
                                      prefixIcon:
                                      getAdaptiveIcon(iconName: 'calendar_today', defaultIcon: Icons.calendar_today,
                                        color: Theme.of(context).colorScheme.primary,
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
                                        selectedStartDate = date;
                                        startDateController.text =
                                            DateFormat('dd.MM.yyyy').format(date);
                                      }
                                    },
                                    validator: (value) =>
                                    value?.isEmpty == true ? 'Bitte Startdatum wählen' : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: endDateController,
                                    decoration: InputDecoration(
                                      labelText: 'Enddatum *',
                                      border: const OutlineInputBorder(),
                                      filled: true,
                                      prefixIcon:
                                      getAdaptiveIcon(iconName: 'calendar_today', defaultIcon: Icons.calendar_today,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    readOnly: true,
                                    onTap: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: selectedEndDate ?? DateTime.now(),
                                        firstDate: selectedStartDate ?? DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                      if (date != null) {
                                        selectedEndDate = date;
                                        endDateController.text =
                                            DateFormat('dd.MM.yyyy').format(date);
                                      }
                                    },
                                    validator: (value) =>
                                    value?.isEmpty == true ? 'Bitte Enddatum wählen' : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Veranstaltungsort
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Veranstaltungsort',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: addressController,
                              decoration: const InputDecoration(
                                labelText: 'Adresse',  // Kein * mehr, da optional
                                border: OutlineInputBorder(),
                                filled: true,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: cityController,
                                    decoration: const InputDecoration(
                                      labelText: 'Stadt *',
                                      border: OutlineInputBorder(),
                                      filled: true,
                                    ),
                                    validator: (value) =>
                                    value?.isEmpty == true ? 'Bitte Stadt eingeben' : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: countryController,
                                    decoration: const InputDecoration(
                                      labelText: 'Land *',
                                      border: OutlineInputBorder(),
                                      filled: true,
                                    ),
                                    validator: (value) =>
                                    value?.isEmpty == true ? 'Bitte Land eingeben' : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Notizen
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Zusätzliche Informationen',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: notesController,
                              decoration: const InputDecoration(
                                labelText: 'Notizen',
                                border: OutlineInputBorder(),
                                filled: true,
                              ),
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Pflichtfeld-Hinweis und Buttons
                    Column(
                      children: [
                        Text(
                          '* Pflichtfelder',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Abbrechen'),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: () async {
                                if (formKey.currentState?.validate() == true &&
                                    selectedStartDate != null &&
                                    selectedEndDate != null) {
                                  final updatedFair = Fair(
                                    id: fair.id,
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
                                    await FirebaseFirestore.instance
                                        .collection('fairs')
                                        .doc(fair.id)
                                        .update(updatedFair.toMap());

                                    if (mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Messe erfolgreich aktualisiert'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Fehler beim Aktualisieren: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                              icon: getAdaptiveIcon(iconName: 'save', defaultIcon: Icons.save,),
                              label: const Text('Speichern'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFairDetails(Fair fair) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        fair.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildDetailRow('Zeitraum',
                    '${DateFormat('dd.MM.yyyy').format(fair.startDate)} - '
                        '${DateFormat('dd.MM.yyyy').format(fair.endDate)}'
                ),
                _buildDetailRow('Kostenstelle', fair.costCenterCode),
                _buildDetailRow('Ort', '${fair.city}, ${fair.country}'),
                _buildDetailRow('Adresse', fair.address),
                if (fair.notes?.isNotEmpty == true) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Notizen',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(fair.notes!),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Schließen'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showEditFairDialog(fair);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Bearbeiten'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
            icon: getAdaptiveIcon(iconName: 'delete', defaultIcon: Icons.delete,),
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

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }}