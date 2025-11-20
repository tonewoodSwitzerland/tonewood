import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../icon_helper.dart';


class ServiceDialogs {
  static void showAddServiceDialog(BuildContext context) {
    final nameController = TextEditingController();
    final nameEnController = TextEditingController();
    final descriptionController = TextEditingController();
    final descriptionEnController = TextEditingController();
    final priceController = TextEditingController();

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
                              iconName: 'add_business',
                              defaultIcon: Icons.add_business,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Neue Dienstleistung',
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
                              hintText: 'z.B. Lohnbehandlung Thermo',
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
                            autofocus: true,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: nameEnController,
                            decoration: InputDecoration(
                              labelText: 'Name (English)',
                              hintText: 'e.g. Thermal Treatment Service',
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
                              hintText: 'Optionale Beschreibung der Dienstleistung',
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
                              hintText: '0.00',
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
                                      await FirebaseFirestore.instance.collection('services').add({
                                        'name': nameController.text.trim(),
                                        'name_en': nameEnController.text.trim(),
                                        'description': descriptionController.text.trim(),
                                        'description_en': descriptionEnController.text.trim(),
                                        'price_CHF': double.parse(priceController.text.replaceAll(',', '.')),
                                        'created_at': FieldValue.serverTimestamp(),
                                        'updated_at': FieldValue.serverTimestamp(),
                                      });
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Dienstleistung wurde angelegt'),
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
}