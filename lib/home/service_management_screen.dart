import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../constants.dart';
import '../services/icon_helper.dart';
import '../services/pdf_generators/service_dialogs.dart';

class ServicesManagementScreen extends StatefulWidget {
  const ServicesManagementScreen({Key? key}) : super(key: key);

  @override
  State<ServicesManagementScreen> createState() => _ServicesManagementScreenState();
}

class _ServicesManagementScreenState extends State<ServicesManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteService(String serviceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            getAdaptiveIcon(iconName: 'warning', defaultIcon: Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('Dienstleistung löschen?'),
          ],
        ),
        content: const Text(
          'Möchtest du diese Dienstleistung wirklich löschen? '
              'Diese Aktion kann nicht rückgängig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('services')
            .doc(serviceId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dienstleistung wurde gelöscht'),
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
    }
  }

  void _showEditServiceDialog(DocumentSnapshot service) {
    final data = service.data() as Map<String, dynamic>;
    final nameController = TextEditingController(text: data['name']);
    final nameEnController = TextEditingController(text: data['name_en'] ?? '');
    final descriptionController = TextEditingController(text: data['description']);
    final descriptionEnController = TextEditingController(text: data['description_en'] ?? '');
    final priceController = TextEditingController(text: data['price_CHF'].toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      spreadRadius: 0.5,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Drag-Indikator
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: getAdaptiveIcon(
                              iconName: 'edit_note',
                              defaultIcon: Icons.edit_note,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Dienstleistung bearbeiten',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: getAdaptiveIcon(
                                iconName: 'close',
                                defaultIcon: Icons.close,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Hauptinhalt
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 5, 20, 20),
                        children: [
                          TextFormField(
                            controller: nameController,
                            decoration: InputDecoration(
                              labelText: 'Name (Deutsch) *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              prefixIcon: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: getAdaptiveIcon(
                                  iconName: 'engineering',
                                  defaultIcon: Icons.engineering,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: nameEnController,
                            decoration: InputDecoration(
                              labelText: 'Name (English)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              prefixIcon: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: getAdaptiveIcon(
                                  iconName: 'language',
                                  defaultIcon: Icons.language,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: descriptionController,
                            decoration: InputDecoration(
                              labelText: 'Beschreibung (Deutsch)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              prefixIcon: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: getAdaptiveIcon(
                                  iconName: 'description',
                                  defaultIcon: Icons.description,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                              ),
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: descriptionEnController,
                            decoration: InputDecoration(
                              labelText: 'Beschreibung (English)',
                              hintText: 'Optional description in English',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              prefixIcon: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: getAdaptiveIcon(
                                  iconName: 'language',
                                  defaultIcon: Icons.language,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                              ),
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: priceController,
                            decoration: InputDecoration(
                              labelText: 'Preis in CHF *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              suffixText: 'CHF',
                              prefixIcon: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: getAdaptiveIcon(
                                  iconName: 'payments',
                                  defaultIcon: Icons.payments,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                              ),
                            ),
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '* Pflichtfelder',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.outline,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    if (nameController.text.isEmpty || priceController.text.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Bitte alle Pflichtfelder ausfüllen'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                      return;
                                    }

                                    try {
                                      await FirebaseFirestore.instance
                                          .collection('services')
                                          .doc(service.id)
                                          .update({
                                        'name': nameController.text.trim(),
                                        'name_en': nameEnController.text.trim(),
                                        'description': descriptionController.text.trim(),
                                        'description_en': descriptionEnController.text.trim(),
                                        'price_CHF': double.parse(priceController.text.replaceAll(',', '.')),
                                        'updated_at': FieldValue.serverTimestamp(),
                                      });

                                      if (mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Dienstleistung wurde aktualisiert'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Fehler beim Speichern: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                                  icon: getAdaptiveIcon(
                                    iconName: 'save',
                                    defaultIcon: Icons.save,
                                    color: Colors.white,
                                  ),
                                  label: const Text('Speichern'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    backgroundColor: Theme.of(context).primaryColor,
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dienstleistungen verwalten'),
        actions: [
          IconButton(
            icon: getAdaptiveIcon(iconName: 'add', defaultIcon: Icons.add),
            onPressed: () =>ServiceDialogs.showAddServiceDialog(context),
            tooltip: 'Neue Dienstleistung',
          ),
        ],
      ),
      body: Column(
        children: [
          // Suchfeld
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Dienstleistung suchen...',
                prefixIcon: getAdaptiveIcon(iconName: 'search', defaultIcon: Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          // Liste der Dienstleistungen
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('services')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Fehler: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final services = snapshot.data?.docs ?? [];

                // Filter basierend auf Suchbegriff
                final filteredServices = services.where((service) {
                  final data = service.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final nameEn = (data['name_en'] ?? '').toString().toLowerCase();
                  final description = (data['description'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) ||
                      nameEn.contains(_searchQuery) ||
                      description.contains(_searchQuery);
                }).toList();

                if (filteredServices.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        getAdaptiveIcon(
                          iconName: 'engineering',
                          defaultIcon: Icons.engineering,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Keine Dienstleistungen vorhanden'
                              : 'Keine Dienstleistungen gefunden',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => ServiceDialogs.showAddServiceDialog(context),
                            icon: getAdaptiveIcon(iconName: 'add', defaultIcon: Icons.add),
                            label: const Text('Erste Dienstleistung anlegen'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredServices.length,
                  itemBuilder: (context, index) {
                    final service = filteredServices[index];
                    final data = service.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: getAdaptiveIcon(
                            iconName: 'engineering',
                            defaultIcon: Icons.engineering,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        title: Text(
                          data['name'] ?? 'Unbenannte Dienstleistung',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (data['name_en'] != null && data['name_en'].isNotEmpty)
                              Text(
                                'EN: ${data['name_en']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                                ),
                              ),
                            if (data['description'] != null && data['description'].isNotEmpty)
                              Text(
                                data['description'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (data['description_en'] != null && data['description_en'].isNotEmpty)
                              Text(
                                'EN: ${data['description_en']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey[600],
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              'CHF ${(data['price_CHF'] ?? 0.0).toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: getAdaptiveIcon(iconName: 'edit', defaultIcon: Icons.edit),
                              onPressed: () => _showEditServiceDialog(service),
                              tooltip: 'Bearbeiten',
                            ),
                            IconButton(
                              icon: getAdaptiveIcon(
                                iconName: 'delete',
                                defaultIcon: Icons.delete,
                                color: Colors.red,
                              ),
                              onPressed: () => _deleteService(service.id),
                              tooltip: 'Löschen',
                            ),
                          ],
                        ),
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


}