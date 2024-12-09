// In lib/screens/production_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';
import 'add_product_screen.dart';

class ProductionScreen extends StatefulWidget {
  final bool isDialog;
  final Function(String)? onProductSelected;

  const ProductionScreen({
    Key? key,
    this.isDialog = false,
    this.onProductSelected,
  }) : super(key: key);

  @override
  ProductionScreenState createState() => ProductionScreenState();
}

class ProductionScreenState extends State<ProductionScreen> {
  final TextEditingController searchController = TextEditingController();
  String searchTerm = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: widget.isDialog
            ? TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: 'Suchen...',
            border: InputBorder.none,
          ),
          onChanged: (value) => setState(() => searchTerm = value.toLowerCase()),
        )
            : const Text('Produktion'),
        actions: [
          if (widget.isDialog)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('production')
            .orderBy('product_name')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Fehler: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data!.docs.where((doc) {
            if (searchTerm.isEmpty) return true;

            final data = doc.data() as Map<String, dynamic>;
            return '${data['product_name']} ${doc.id}'.toLowerCase().contains(searchTerm);
          }).toList();

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Keine Produkte gefunden'),
                  const SizedBox(height: 24),
                  if (!widget.isDialog)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddProductScreen(
                              editMode: false,
                              isProduction: true,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Neues Produkt anlegen'),
                    ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final doc = items[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(
                    data['product_name'] ?? 'Unbekanntes Produkt',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Artikelnummer: ${doc.id}'),
                      // const SizedBox(height: 4),
                      // Text('Bestand: ${data['quantity']} ${data['unit'] ?? 'Stück'}'),
                    ],
                  ),
                  onTap: widget.onProductSelected != null
                      ? () => widget.onProductSelected!(doc.id)
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}