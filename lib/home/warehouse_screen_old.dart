// import 'dart:math';
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import '../constants.dart';
//
// class WarehouseScreen extends StatefulWidget {
//   const WarehouseScreen({required Key key}) : super(key: key);
//
//   @override
//   WarehouseScreenState createState() => WarehouseScreenState();
// }
//
// class WarehouseScreenState extends State<WarehouseScreen> {
//   // Filter states
//   List<String> selectedInstrumentCodes = [];
//   List<String> selectedPartCodes = [];
//   List<String> selectedWoodCodes = [];
//   List<String> selectedQualityCodes = [];
//   String? selectedYear;
//   String? selectedUnit;
//   bool haselfichteFilter = false;
//   bool moonwoodFilter = false;
//   bool thermallyTreatedFilter = false;
//   bool fscFilter = false;
// // Dropdown data from Firestore
//   List<QueryDocumentSnapshot>? instruments;
//   List<QueryDocumentSnapshot>? parts;
//   List<QueryDocumentSnapshot>? woodTypes;
//   List<QueryDocumentSnapshot>? qualities;
//   List<String> units = ['Stück', 'Kg', 'Palette', 'm³'];
//
//
//   @override
//   void initState() {
//     super.initState();
//     _loadDropdownData();
//   }
//
//
//   Future<int> _getAvailableQuantity(String barcode) async {
//     // Aktuellen Bestand abrufen
//     final productDoc = await FirebaseFirestore.instance
//         .collection('products')
//         .doc(barcode)
//         .get();
//
//     final currentStock = (productDoc.data()?['quantity'] ?? 0) as int;
//
//     // Temporär gebuchte Menge abrufen
//     final tempBasketDoc = await FirebaseFirestore.instance
//         .collection('temporary_basket')
//         .where('product_id', isEqualTo: barcode)
//         .get();
//
//     final reservedQuantity = tempBasketDoc.docs.fold<int>(
//       0,
//           (sum, doc) => sum + (doc.data()['quantity'] as int),
//     );
//
//     return currentStock - reservedQuantity;
//   }
//
//   Future<void> _addToTemporaryBasket(Map<String, dynamic> productData, int quantity) async {
//     await FirebaseFirestore.instance
//         .collection('temporary_basket')
//         .add({
//       'product_id': productData['barcode'],
//       'product_name': productData['product_name'],
//       'quantity': quantity,
//       'timestamp': FieldValue.serverTimestamp(),
//       'price_per_unit': productData['price_CHF'],
//       'unit': productData['unit'],
//       'instrument_name': productData['instrument_name'],
//       'instrument_code': productData['instrument_code'],
//       'part_name': productData['part_name'],
//       'part_code': productData['part_code'],
//       'wood_name': productData['wood_name'],
//       'wood_code': productData['wood_code'],
//       'quality_name': productData['quality_name'],
//       'quality_code': productData['quality_code'],
//     });
//   }
//
//
//   void _showProductDetails(Map<String, dynamic> data) {
//     TextEditingController quantityController = TextEditingController();
//
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text(data['product_name']?.toString() ?? 'Produktdetails'),
//           content: SingleChildScrollView(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 _detailRow('Barcode', data['barcode']?.toString()),
//                 _detailRow('Instrument', '${data['instrument_name']} (${data['instrument_code']})'),
//                 _detailRow('Bauteil', '${data['part_name']} (${data['part_code']})'),
//                 _detailRow('Holzart', '${data['wood_name']} (${data['wood_code']})'),
//                 _detailRow('Qualität', '${data['quality_name']} (${data['quality_code']})'),
//                 _detailRow('Jahrgang', data['year'] != null ? '20${data['year']}' : 'N/A'),
//                 _detailRow('Bestand', '${data['quantity']?.toString() ?? '0'} ${data['unit']?.toString() ?? ''}'),
//                 _detailRow('Preis CHF', data['price_CHF']?.toString()),
//                 _booleanRow('Thermobehandelt', data['thermally_treated']),
//                 _booleanRow('Haselfichte', data['haselfichte']),
//                 _booleanRow('Mondholz', data['moonwood']),
//                 _booleanRow('FSC 100%', data['FSC_100']),
//                 if (data['custom_name'] != null)
//                   _detailRow('Spezialbezeichnung', data['custom_name']),
//                 if (data['last_modified'] != null)
//                   _detailRow('Zuletzt bearbeitet', (data['last_modified'] as Timestamp).toDate().toString()),
//                 if (data['created_at'] != null)
//                   _detailRow('Erstellt am', (data['created_at'] as Timestamp).toDate().toString()),
//                 const Divider(height: 32),
//
//                 // Neue Sektion für Warenkorb
//                 const Text(
//                   'In den Warenkorb legen',
//                   style: TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//
//                 // Anzeige des verfügbaren Bestands
//                 FutureBuilder<int>(
//                   future: _getAvailableQuantity(data['barcode']),
//                   builder: (context, snapshot) {
//                     if (snapshot.hasData) {
//                       return Text(
//                         'Verfügbarer Bestand: ${snapshot.data} ${data['unit'] ?? 'Stück'}',
//                         style: TextStyle(color: Colors.grey[600]),
//                       );
//                     }
//                     return const CircularProgressIndicator();
//                   },
//                 ),
//
//                 const SizedBox(height: 16),
//
//                 TextFormField(
//                   controller: quantityController,
//                   decoration: const InputDecoration(
//                     labelText: 'Menge',
//                     border: OutlineInputBorder(),
//                     helperText: 'Menge für Warenkorb eingeben',
//                   ),
//                   keyboardType: TextInputType.number,
//                   inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                 ),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text('Schließen'),
//             ),
//             ElevatedButton(
//               onPressed: () async {
//                 if (quantityController.text.isEmpty) return;
//
//                 final quantity = int.parse(quantityController.text);
//                 final availableQuantity = await _getAvailableQuantity(data['barcode']);
//
//                 if (quantity <= 0) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(
//                       content: Text('Bitte gib eine gültige Menge ein'),
//                       backgroundColor: Colors.orange,
//                     ),
//                   );
//                   return;
//                 }
//
//                 if (quantity > availableQuantity) {
//                   AppToast.show(message: "Nicht genügend Bestand verfügbar", height: h);
//                   return;
//                 }
//
//                 await _addToTemporaryBasket(data, quantity);
//                 Navigator.pop(context);
//
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(
//                     content: Text('Produkt wurde dem Warenkorb hinzugefügt'),
//                     backgroundColor: Colors.green,
//                   ),
//                 );
//               },
//               child: const Text('In den Warenkorb'),
//             ),
//           ],
//         );
//       },
//     );
//   }
//
// // Hilfsmethoden für die Anzeige
//   Widget _detailRow(String label, String? value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4.0),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SizedBox(
//             width: 120,
//             child: Text(
//               '$label:',
//               style: const TextStyle(fontWeight: FontWeight.bold),
//             ),
//           ),
//           Expanded(
//             child: Text(value ?? 'N/A'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _booleanRow(String label, bool? value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4.0),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SizedBox(
//             width: 120,
//             child: Text(
//               '$label:',
//               style: const TextStyle(fontWeight: FontWeight.bold),
//             ),
//           ),
//           Expanded(
//             child: Text(value == true ? 'Ja' : 'Nein'),
//           ),
//         ],
//       ),
//     );
//   }
//   Future<void> _loadDropdownData() async {
//     try {
//       final instrumentsSnapshot = await FirebaseFirestore.instance
//           .collection('instruments')
//           .orderBy('code')
//           .get();
//       final partsSnapshot = await FirebaseFirestore.instance
//           .collection('parts')
//           .orderBy('code')
//           .get();
//       final woodTypesSnapshot = await FirebaseFirestore.instance
//           .collection('wood_types')
//           .orderBy('code')
//           .get();
//       final qualitiesSnapshot = await FirebaseFirestore.instance
//           .collection('qualities')
//           .orderBy('code')
//           .get();
//
//       setState(() {
//         instruments = instrumentsSnapshot.docs;
//         parts = partsSnapshot.docs;
//         woodTypes = woodTypesSnapshot.docs;
//         qualities = qualitiesSnapshot.docs;
//       });
//     } catch (e) {
//       print('Fehler beim Laden der Filterdaten: $e');
//     }
//   }
//   // Query builder based on filters
//   Query<Map<String, dynamic>> buildQuery() {
//     Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('products');
//
//     if (selectedInstrumentCodes.isNotEmpty) {
//       query = query.where('instrument_code', whereIn: selectedInstrumentCodes);
//     }
//     if (selectedPartCodes.isNotEmpty) {
//       query = query.where('part_code', whereIn: selectedPartCodes);
//     }
//     if (selectedWoodCodes.isNotEmpty) {
//       query = query.where('wood_code', whereIn: selectedWoodCodes);
//     }
//     if (selectedQualityCodes.isNotEmpty) {
//       query = query.where('quality_code', whereIn: selectedQualityCodes);
//     }
//     if (selectedYear != null) {
//       query = query.where('year', isEqualTo: selectedYear);
//     }
//     if (selectedUnit != null) {
//       query = query.where('unit', isEqualTo: selectedUnit);
//     }
//     if (haselfichteFilter) {
//       query = query.where('haselfichte', isEqualTo: true);
//     }
//     if (moonwoodFilter) {
//       query = query.where('moonwood', isEqualTo: true);
//     }
//     if (thermallyTreatedFilter) {
//       query = query.where('thermally_treated', isEqualTo: true);
//     }
//     if (fscFilter) {
//       query = query.where('FSC_100', isEqualTo: true);
//     }
//
//     return query;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     SizeConfig().init(context);
//     final screenWidth = MediaQuery.of(context).size.width;
//     final isDesktopLayout = screenWidth > ResponsiveBreakpoints.tablet;
//
//     return StreamBuilder<User?>(
//         stream: FirebaseAuth.instance.authStateChanges(),
//         builder: (context, userSnapshot) {
//           if (!userSnapshot.hasData) {
//             return const Center(child: CircularProgressIndicator());
//           }
//
//           return Scaffold(
//             appBar: AppBar(
//               title: const Text('Lager',style: headline4_0,),
//               centerTitle: true,
//               // Nur für Mobile den Filter-Button zeigen
//               actions: !isDesktopLayout ? [
//                 IconButton(
//                   icon: const Icon(Icons.filter_list),
//                   onPressed: () => _showFilterDialog(),
//                 ),
//               ] : null,
//             ),
//             body: isDesktopLayout
//                 ? _buildDesktopLayout()
//                 : _buildMobileLayout(),
//           );
//         }
//     );
//   }
//
//   Widget _buildDesktopLayout() {
//     return Row(
//       children: [
//         // Permanenter Filterbereich links
//         Container(
//           width: 300,
//           decoration: BoxDecoration(
//             border: Border(
//               right: BorderSide(
//                 color: Colors.grey.shade300,
//                 width: 1,
//               ),
//             ),
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: const Text(
//                   'Filter',
//                   style: TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//               Expanded(
//                 child: _buildFilterSection(),
//               ),
//             ],
//           ),
//         ),
//         // Produktliste rechts
//         Expanded(
//           child: _buildProductList(),
//         ),
//       ],
//     );
//   }
//   Widget _buildActiveFiltersChips() {
//     String getNameForCode(List<QueryDocumentSnapshot> docs, String code) {
//       try {
//         final doc = docs.firstWhere(
//               (doc) => (doc.data() as Map<String, dynamic>)['code'] == code,
//         );
//         return (doc.data() as Map<String, dynamic>)['name'] as String;
//       } catch (e) {
//         return code;
//       }
//     }
//
//     return SingleChildScrollView(
//       scrollDirection: Axis.horizontal,
//       padding: const EdgeInsets.all(8.0),
//       child: Row(
//         children: [
//           if (instruments != null)
//             ...selectedInstrumentCodes.map((code) => Padding(
//               padding: const EdgeInsets.only(right: 8.0),
//               child: Chip(
//                 label: Text('${getNameForCode(instruments!, code)} ($code)'),
//                 deleteIcon: const Icon(Icons.close, size: 18),
//                 onDeleted: () {
//                   setState(() {
//                     selectedInstrumentCodes.remove(code);
//                   });
//                 },
//               ),
//             )),
//           if (parts != null)
//             ...selectedPartCodes.map((code) => Padding(
//               padding: const EdgeInsets.only(right: 8.0),
//               child: Chip(
//                 label: Text('${getNameForCode(parts!, code)} ($code)'),
//                 deleteIcon: const Icon(Icons.close, size: 18),
//                 onDeleted: () {
//                   setState(() {
//                     selectedPartCodes.remove(code);
//                   });
//                 },
//               ),
//             )),
//           if (woodTypes != null)
//             ...selectedWoodCodes.map((code) => Padding(
//               padding: const EdgeInsets.only(right: 8.0),
//               child: Chip(
//                 label: Text('${getNameForCode(woodTypes!, code)} ($code)'),
//                 deleteIcon: const Icon(Icons.close, size: 18),
//                 onDeleted: () {
//                   setState(() {
//                     selectedWoodCodes.remove(code);
//                   });
//                 },
//               ),
//             )),
//           if (qualities != null)
//             ...selectedQualityCodes.map((code) => Padding(
//               padding: const EdgeInsets.only(right: 8.0),
//               child: Chip(
//                 label: Text('${getNameForCode(qualities!, code)} ($code)'),
//                 deleteIcon: const Icon(Icons.close, size: 18),
//                 onDeleted: () {
//                   setState(() {
//                     selectedQualityCodes.remove(code);
//                   });
//                 },
//               ),
//             )),
//           if (selectedYear != null)
//             Padding(
//               padding: const EdgeInsets.only(right: 8.0),
//               child: Chip(
//                 label: Text('Jahrgang: 20$selectedYear'),
//                 deleteIcon: const Icon(Icons.close, size: 18),
//                 onDeleted: () {
//                   setState(() {
//                     selectedYear = null;
//                   });
//                 },
//               ),
//             ),
//           if (selectedUnit != null)
//             Padding(
//               padding: const EdgeInsets.only(right: 8.0),
//               child: Chip(
//                 label: Text('Einheit: $selectedUnit'),
//                 deleteIcon: const Icon(Icons.close, size: 18),
//                 onDeleted: () {
//                   setState(() {
//                     selectedUnit = null;
//                   });
//                 },
//               ),
//             ),
//           if (haselfichteFilter)
//             Padding(
//               padding: const EdgeInsets.only(right: 8.0),
//               child: Chip(
//                 label: const Text('Haselfichte'),
//                 deleteIcon: const Icon(Icons.close, size: 18),
//                 onDeleted: () {
//                   setState(() {
//                     haselfichteFilter = false;
//                   });
//                 },
//               ),
//             ),
//           if (moonwoodFilter)
//             Padding(
//               padding: const EdgeInsets.only(right: 8.0),
//               child: Chip(
//                 label: const Text('Mondholz'),
//                 deleteIcon: const Icon(Icons.close, size: 18),
//                 onDeleted: () {
//                   setState(() {
//                     moonwoodFilter = false;
//                   });
//                 },
//               ),
//             ),
//           if (thermallyTreatedFilter)
//             Padding(
//               padding: const EdgeInsets.only(right: 8.0),
//               child: Chip(
//                 label: const Text('Thermobehandelt'),
//                 deleteIcon: const Icon(Icons.close, size: 18),
//                 onDeleted: () {
//                   setState(() {
//                     thermallyTreatedFilter = false;
//                   });
//                 },
//               ),
//             ),
//           if (fscFilter)
//             Padding(
//               padding: const EdgeInsets.only(right: 8.0),
//               child: Chip(
//                 label: const Text('FSC 100%'),
//                 deleteIcon: const Icon(Icons.close, size: 18),
//                 onDeleted: () {
//                   setState(() {
//                     fscFilter = false;
//                   });
//                 },
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildMobileLayout() {
//     return Column(
//       children: [
//         if (_hasActiveFilters())
//           _buildActiveFiltersChips(),
//         Expanded(
//           child: _buildProductList(),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildFilterSection() {
//     return SingleChildScrollView(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 8.0),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             if (instruments != null)
//               _buildMultiSelectDropdown(
//                 label: 'Instrument',
//                 options: instruments!,
//                 selectedValues: selectedInstrumentCodes,
//                 onChanged: (newSelection) {
//                   setState(() {
//                     selectedInstrumentCodes = newSelection;
//                   });
//                 },
//               ),
//             const SizedBox(height: 16),
//             if (parts != null)
//               _buildMultiSelectDropdown(
//                 label: 'Bauteil',
//                 options: parts!,
//                 selectedValues: selectedPartCodes,
//                 onChanged: (newSelection) {
//                   setState(() {
//                     selectedPartCodes = newSelection;
//                   });
//                 },
//               ),
//             const SizedBox(height: 16),
//             if (woodTypes != null)
//               _buildMultiSelectDropdown(
//                 label: 'Holzart',
//                 options: woodTypes!,
//                 selectedValues: selectedWoodCodes,
//                 onChanged: (newSelection) {
//                   setState(() {
//                     selectedWoodCodes = newSelection;
//                   });
//                 },
//               ),
//             const SizedBox(height: 16),
//             if (qualities != null)
//               _buildMultiSelectDropdown(
//                 label: 'Qualität',
//                 options: qualities!,
//                 selectedValues: selectedQualityCodes,
//                 onChanged: (newSelection) {
//                   setState(() {
//                     selectedQualityCodes = newSelection;
//                   });
//                 },
//               ),
//             // ... Rest der Filter wie bisher ...
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildFilterCheckbox(String label, bool value, Function(bool?) onChanged) {
//     return CheckboxListTile(
//       title: Text(label),
//       value: value,
//       onChanged: onChanged,
//       dense: true,
//       contentPadding: EdgeInsets.zero,
//     );
//   }
//
//   Widget _buildProductList() {
//     return StreamBuilder<QuerySnapshot>(
//       stream: buildQuery().snapshots(),
//       builder: (context, snapshot) {
//         if (snapshot.hasError) {
//           return const Center(child: Text('Ein Fehler ist aufgetreten'));
//         }
//
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Center(child: CircularProgressIndicator());
//         }
//
//         // Sicherstellen, dass snapshot.data nicht null ist
//         if (!snapshot.hasData || snapshot.data == null || snapshot.data!.docs.isEmpty) {
//           return const Center(child: Text('Keine Produkte gefunden'));
//         }
//
//         return ListView.builder(
//           itemCount: snapshot.data!.docs.length,
//           padding: const EdgeInsets.all(16),
//           itemBuilder: (context, index) {
//             final doc = snapshot.data!.docs[index];
//             // Sicheres Casting der Daten
//             final data = doc.data() as Map<String, dynamic>? ?? {};
//
//             return Card(
//               margin: const EdgeInsets.only(bottom: 12),
//               child: ListTile(
//                 contentPadding: const EdgeInsets.all(16),
//                 title: Row(
//                   children: [
//                     Expanded(  // Wichtig: Text in Expanded einwickeln
//                       child: Text(
//                         data['product_name']?.toString() ?? 'Unbenanntes Produkt',
//                         style: const TextStyle(fontWeight: FontWeight.bold),
//                         overflow: TextOverflow.ellipsis,  // Fügt ... hinzu wenn der Text zu lang ist
//                       ),
//                     ),
//                   ],
//                 ),
//                 subtitle: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const SizedBox(height: 8),
//                     // Auch die Subtitle-Texte mit Overflow protection
//                     Text(
//                       'Instrument: ${data['instrument_name']?.toString() ?? 'N/A'} (${data['instrument_code']?.toString() ?? 'N/A'})',
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                     Text(
//                       'Bauteil: ${data['part_name']?.toString() ?? 'N/A'} (${data['part_code']?.toString() ?? 'N/A'})',
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                     Text(
//                       'Holzart: ${data['wood_name']?.toString() ?? 'N/A'} (${data['wood_code']?.toString() ?? 'N/A'})',
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   ],
//                 ),
//                 trailing: SizedBox(  // Feste Breite für trailing
//                   width: 80,
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     crossAxisAlignment: CrossAxisAlignment.end,  // Rechtsbündig
//                     children: [
//                       const Text('Bestand'),
//                       Text(
//                         '${data['quantity']?.toString() ?? '0'} ${data['unit']?.toString() ?? ''}',
//                         style: Theme.of(context).textTheme.titleSmall,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ],
//                   ),
//                 ),
//                 onTap: () => _showProductDetails(data),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
//
//
//   Widget _buildMultiSelectDropdown({
//     required String label,
//     required List<QueryDocumentSnapshot> options,
//     required List<String> selectedValues,
//     required Function(List<String>) onChanged,
//   }) {
//     String getNameForCode(String code) {
//       try {
//         final doc = options.firstWhere(
//               (doc) => (doc.data() as Map<String, dynamic>)['code'] == code,
//         );
//         return (doc.data() as Map<String, dynamic>)['name'] as String;
//       } catch (e) {
//         return code; // Fallback zum Code falls kein Name gefunden wird
//       }
//     }
//
//     return Material(
//       color: Colors.transparent,
//       child: Theme(
//         data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
//         child: ExpansionTile(
//           title: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 label,
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//               Text(
//                 selectedValues.isEmpty
//                     ? 'Keine Auswahl'
//                     : selectedValues.map((code) =>
//                 '${getNameForCode(code)} ($code)').join(', '),
//                 style: TextStyle(
//                   fontSize: 14,
//                   color: Colors.grey[600],
//                 ),
//               ),
//             ],
//           ),
//           children: [
//             Container(
//               padding: EdgeInsets.symmetric(horizontal: 16),
//               child: Column(
//                 children: options.map((doc) {
//                   final data = doc.data() as Map<String, dynamic>;
//                   final code = data['code'] as String;
//                   final name = data['name'] as String;
//                   return CheckboxListTile(
//                     title: Text('$name ($code)'),
//                     value: selectedValues.contains(code),
//                     onChanged: (bool? checked) {
//                       List<String> newSelection = List.from(selectedValues);
//                       if (checked ?? false) {
//                         if (!newSelection.contains(code)) {
//                           newSelection.add(code);
//                         }
//                       } else {
//                         newSelection.remove(code);
//                       }
//                       onChanged(newSelection);
//                     },
//                     controlAffinity: ListTileControlAffinity.leading,
//                     dense: true,
//                   );
//                 }).toList(),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//
//   bool _hasActiveFilters() {
//     return selectedInstrumentCodes.isNotEmpty ||
//         selectedPartCodes.isNotEmpty ||
//         selectedWoodCodes.isNotEmpty ||
//         selectedQualityCodes.isNotEmpty ||
//         selectedYear != null ||
//         selectedUnit != null ||
//         haselfichteFilter ||
//         moonwoodFilter ||
//         thermallyTreatedFilter ||
//         fscFilter;
//   }
//   void _showFilterDialog() {
//     showDialog(
//         context: context,
//         builder: (BuildContext context) {
//           return StatefulBuilder(
//             builder: (context, setState) {
//               return Dialog(
//                 child: Container(
//                   width: MediaQuery.of(context).size.width * 0.9,
//                   height: MediaQuery.of(context).size.height * 0.8,
//                   child: Column(
//                     children: [
//                       // Header bleibt gleich
//                       Padding(
//                         padding: const EdgeInsets.all(16.0),
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             const Text(
//                               'Filter',
//                               style: TextStyle(
//                                 fontSize: 20,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             IconButton(
//                               icon: const Icon(Icons.close),
//                               onPressed: () => Navigator.of(context).pop(),
//                             ),
//                           ],
//                         ),
//                       ),
//                       // Content
//                       Expanded(
//                         child: SingleChildScrollView(
//                           padding: const EdgeInsets.symmetric(horizontal: 16.0),
//                           child: Column(
//                             mainAxisSize: MainAxisSize.min,
//                             crossAxisAlignment: CrossAxisAlignment.stretch,
//                             children: [
//                               if (instruments != null)
//                                 _buildMultiSelectDropdown(
//                                   label: 'Instrument',
//                                   options: instruments!,
//                                   selectedValues: selectedInstrumentCodes,
//                                   onChanged: (newSelection) {
//                                     setState(() {
//                                       selectedInstrumentCodes = newSelection;
//                                     });
//                                   },
//                                 ),
//                               const SizedBox(height: 16),
//                               if (parts != null)
//                                 _buildMultiSelectDropdown(
//                                   label: 'Bauteil',
//                                   options: parts!,
//                                   selectedValues: selectedPartCodes,
//                                   onChanged: (newSelection) {
//                                     setState(() {
//                                       selectedPartCodes = newSelection;
//                                     });
//                                   },
//                                 ),
//                               const SizedBox(height: 16),
//                               if (woodTypes != null)
//                                 _buildMultiSelectDropdown(
//                                   label: 'Holzart',
//                                   options: woodTypes!,
//                                   selectedValues: selectedWoodCodes,
//                                   onChanged: (newSelection) {
//                                     setState(() {
//                                       selectedWoodCodes = newSelection;
//                                     });
//                                   },
//                                 ),
//                               const SizedBox(height: 16),
//                               if (qualities != null)
//                                 _buildMultiSelectDropdown(
//                                   label: 'Qualität',
//                                   options: qualities!,
//                                   selectedValues: selectedQualityCodes,
//                                   onChanged: (newSelection) {
//                                     setState(() {
//                                       selectedQualityCodes = newSelection;
//                                     });
//                                   },
//                                 ),
//                               const SizedBox(height: 16),
//                               Card(
//                                 child: Column(
//                                   children: [
//                                     CheckboxListTile(
//                                       title: const Text('Haselfichte'),
//                                       value: haselfichteFilter,
//                                       onChanged: (bool? value) {
//                                         setState(() {
//                                           haselfichteFilter = value ?? false;
//                                         });
//                                       },
//                                     ),
//                                     CheckboxListTile(
//                                       title: const Text('Mondholz'),
//                                       value: moonwoodFilter,
//                                       onChanged: (bool? value) {
//                                         setState(() {
//                                           moonwoodFilter = value ?? false;
//                                         });
//                                       },
//                                     ),
//                                     CheckboxListTile(
//                                       title: const Text('Thermobehandelt'),
//                                       value: thermallyTreatedFilter,
//                                       onChanged: (bool? value) {
//                                         setState(() {
//                                           thermallyTreatedFilter = value ?? false;
//                                         });
//                                       },
//                                     ),
//                                     CheckboxListTile(
//                                       title: const Text('FSC 100%'),
//                                       value: fscFilter,
//                                       onChanged: (bool? value) {
//                                         setState(() {
//                                           fscFilter = value ?? false;
//                                         });
//                                       },
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                       // Buttons
//                       Padding(
//                         padding: const EdgeInsets.all(16.0),
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.end,
//                           children: [
//                             TextButton(
//                               child: const Text('Zurücksetzen'),
//                               onPressed: () {
//                                 setState(() {
//                                   selectedInstrumentCodes.clear();
//                                   selectedPartCodes.clear();
//                                   selectedWoodCodes.clear();
//                                   selectedQualityCodes.clear();
//                                   selectedYear = null;
//                                   selectedUnit = null;
//                                   haselfichteFilter = false;
//                                   moonwoodFilter = false;
//                                   thermallyTreatedFilter = false;
//                                   fscFilter = false;
//                                 });
//                               },
//                             ),
//                             const SizedBox(width: 8),
//                             ElevatedButton(
//                               child: const Text('Anwenden'),
//                               onPressed: () {
//                                 this.setState(() {}); // Trigger rebuild with new filters
//                                 Navigator.of(context).pop();
//                               },
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               );
//             },
//           );
//         }  );
//   }
// }