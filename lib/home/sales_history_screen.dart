// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:intl/intl.dart';
// import 'package:share_plus/share_plus.dart';
// import 'package:http/http.dart' as http;
// import 'package:path_provider/path_provider.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'dart:io';
// import '../constants.dart';
// import '../services/icon_helper.dart';
//
// class SalesFilter {
// DateTime? startDate;
// DateTime? endDate;
// double? minAmount;
// double? maxAmount;
// String? selectedCustomer;
// String? selectedInstrument;
// String? selectedFair;
// String? selectedProduct; // Neu für Artikelfilter
//
// SalesFilter({
//   this.startDate,
//   this.endDate,
//   this.minAmount,
//   this.maxAmount,
//   this.selectedCustomer,
//   this.selectedInstrument,
//   this.selectedFair,
//   this.selectedProduct, // Neu
// });
//
// SalesFilter copyWith({
//   DateTime? startDate,
//   DateTime? endDate,
//   double? minAmount,
//   double? maxAmount,
//   String? selectedCustomer,
//   String? selectedInstrument,
//   String? selectedFair,
//   String? selectedProduct, // Neu
// }) {
//   return SalesFilter(
//     startDate: startDate ?? this.startDate,
//     endDate: endDate ?? this.endDate,
//     minAmount: minAmount ?? this.minAmount,
//     maxAmount: maxAmount ?? this.maxAmount,
//     selectedCustomer: selectedCustomer ?? this.selectedCustomer,
//     selectedInstrument: selectedInstrument ?? this.selectedInstrument,
//     selectedFair: selectedFair ?? this.selectedFair,
//     selectedProduct: selectedProduct ?? this.selectedProduct, // Neu
//   );
// }
// }
//
//
//
// class SalesHistoryScreen extends StatefulWidget {
//   const SalesHistoryScreen({Key? key}) : super(key: key);
//
//   @override
//   SalesHistoryScreenState createState() => SalesHistoryScreenState();
// }
//
// class SalesHistoryScreenState extends State<SalesHistoryScreen> {
//   // Filter states
//
//   bool isLoading = false;
//  SalesFilter activeFilter = SalesFilter();
//   @override
//   Widget build(BuildContext context) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     final isDesktopLayout = screenWidth > ResponsiveBreakpoints.tablet;
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Verkaufshistorie', style: headline4_0),
//         actions: [
//           if (!isDesktopLayout)
//             IconButton(
//                 icon:getAdaptiveIcon(iconName: 'filter_list', defaultIcon: Icons.filter_list,),
//
//               onPressed: _showFilterDialog,
//             ),
//         ],
//       ),
//       body: isDesktopLayout
//           ? _buildDesktopLayout()
//           : _buildMobileLayout(),
//     );
//   }
//
//   Widget _buildDesktopLayout() {
//     return Row(
//       children: [
//         // Filter-Sidebar
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
//           child: _buildFilterSection(),
//         ),
//         // Lieferschein-Liste
//         Expanded(
//           child: _buildSalesList(),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildMobileLayout() {
//     return Column(
//       children: [
//         if (_hasActiveFilters())
//           _buildActiveFiltersChips(),
//         Expanded(
//           child: _buildSalesList(),
//         ),
//       ],
//     );
//   }
//   // Füge diese neue Methode zur SalesHistoryScreenState Klasse hinzu
//   Widget _buildProductFilter() {
//     return StreamBuilder<QuerySnapshot>(
//       stream: FirebaseFirestore.instance
//           .collection('inventory')
//           .orderBy('product_name')
//           .snapshots(),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) return const SizedBox();
//
//         return DropdownButtonFormField<String>(
//           decoration: const InputDecoration(
//             labelText: 'Artikel',
//             border: OutlineInputBorder(),
//           ),
//           value: activeFilter.selectedProduct,
//           items: [
//             const DropdownMenuItem<String>(
//               value: null,
//               child: Text('Alle Artikel'),
//             ),
//             ...snapshot.data!.docs.map((doc) {
//               final data = doc.data() as Map<String, dynamic>;
//               return DropdownMenuItem<String>(
//                 value: doc.id,
//                 child: Text(data['product_name'] ?? ''),
//               );
//             }).toList(),
//           ],
//           onChanged: (value) {
//             setState(() => activeFilter.selectedProduct = value);
//           },
//         );
//       },
//     );
//   }
//
// // Aktualisiere die _buildFilterSection Methode
//   Widget _buildFilterSection() {
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Filter',
//             style: TextStyle(
//               fontSize: 20,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 16),
//           _buildDateRangePicker(),
//           const SizedBox(height: 16),
//           _buildAmountRangeFilter(),
//           const SizedBox(height: 16),
//           _buildCustomerFilter(),
//           const SizedBox(height: 16),
//           _buildProductFilter(), // Neu
//           const SizedBox(height: 16),
//           _buildFairFilter(),
//           const SizedBox(height: 16),
//           _buildInstrumentFilter(),
//         ],
//       ),
//     );
//   }
//
//
// // Füge diese neue Methode zur SalesHistoryScreenState Klasse hinzu
//   Widget _buildFairFilter() {
//     return StreamBuilder<QuerySnapshot>(
//       stream: FirebaseFirestore.instance
//           .collection('fairs')
//           .orderBy('name')
//           .snapshots(),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) return const SizedBox();
//
//         return DropdownButtonFormField<String>(
//           decoration: const InputDecoration(
//             labelText: 'Messe',
//             border: OutlineInputBorder(),
//           ),
//           value: activeFilter.selectedFair,
//           items: [
//             const DropdownMenuItem<String>(
//               value: null,
//               child: Text('Alle Messen'),
//             ),
//             ...snapshot.data!.docs.map((doc) {
//               final data = doc.data() as Map<String, dynamic>;
//               return DropdownMenuItem<String>(
//                 value: doc.id,
//                 child: Text(data['name'] ?? ''),
//               );
//             }).toList(),
//           ],
//           onChanged: (value) {
//             setState(() => activeFilter.selectedFair = value);
//           },
//         );
//       },
//     );
//   }
//
//
//
//   Widget _buildDateRangePicker() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text('Zeitraum'),
//         const SizedBox(height: 8),
//         Row(
//           children: [
//             Expanded(
//               child: TextButton.icon(
//                 icon: getAdaptiveIcon(iconName: 'calendar_today', defaultIcon: Icons.calendar_today),
//                 label: Text(
//                   activeFilter.startDate != null
//                       ? DateFormat('dd.MM.yyyy').format(activeFilter.startDate!)
//                       : 'Von',
//                 ),
//                 onPressed: () async {
//                   final date = await showDatePicker(
//                     context: context,
//                     initialDate: activeFilter.startDate ?? DateTime.now(),
//                     firstDate: DateTime(2020),
//                     lastDate: DateTime.now(),
//                   );
//                   if (date != null) {
//                     setState(() => activeFilter.startDate = date);
//                   }
//                 },
//               ),
//             ),
//             const SizedBox(width: 8),
//             Expanded(
//               child: TextButton.icon(
//                 icon: getAdaptiveIcon(iconName: 'calendar_today', defaultIcon: Icons.calendar_today),
//                 label: Text(
//                   activeFilter.endDate != null
//                       ? DateFormat('dd.MM.yyyy').format(activeFilter.endDate!)
//                       : 'Bis',
//                 ),
//                 onPressed: () async {
//                   final date = await showDatePicker(
//                     context: context,
//                     initialDate: activeFilter.endDate ?? DateTime.now(),
//                     firstDate: DateTime(2020),
//                     lastDate: DateTime.now(),
//                   );
//                   if (date != null) {
//                     setState(() => activeFilter.endDate = date);
//                   }
//                 },
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }
//
// // _buildAmountRangeFilter anpassen
//   Widget _buildAmountRangeFilter() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text('Betrag (CHF)'),
//         const SizedBox(height: 8),
//         Row(
//           children: [
//             Expanded(
//               child: TextField(
//                 decoration: const InputDecoration(
//                   hintText: 'Min',
//                   border: OutlineInputBorder(),
//                 ),
//                 keyboardType: TextInputType.number,
//                 controller: TextEditingController(
//                   text: activeFilter.minAmount?.toString() ?? '',
//                 ),
//                 onChanged: (value) {
//                   setState(() {
//                     activeFilter.minAmount = double.tryParse(value);
//                   });
//                 },
//               ),
//             ),
//             const SizedBox(width: 8),
//             Expanded(
//               child: TextField(
//                 decoration: const InputDecoration(
//                   hintText: 'Max',
//                   border: OutlineInputBorder(),
//                 ),
//                 keyboardType: TextInputType.number,
//                 controller: TextEditingController(
//                   text: activeFilter.maxAmount?.toString() ?? '',
//                 ),
//                 onChanged: (value) {
//                   setState(() {
//                     activeFilter.maxAmount = double.tryParse(value);
//                   });
//                 },
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }
//
// // _buildCustomerFilter anpassen
//   Widget _buildCustomerFilter() {
//     return StreamBuilder<QuerySnapshot>(
//       stream: FirebaseFirestore.instance
//           .collection('customers')
//           .orderBy('company')
//           .snapshots(),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) return const SizedBox();
//
//         return DropdownButtonFormField<String>(
//           decoration: const InputDecoration(
//             labelText: 'Kunde',
//             border: OutlineInputBorder(),
//           ),
//           value: activeFilter.selectedCustomer,
//           items: [
//             const DropdownMenuItem<String>(
//               value: null,
//               child: Text('Alle Kunden'),
//             ),
//             ...snapshot.data!.docs.map((doc) {
//               final data = doc.data() as Map<String, dynamic>;
//               return DropdownMenuItem<String>(
//                 value: doc.id,
//                 child: Text(data['company'] ?? ''),
//               );
//             }).toList(),
//           ],
//           onChanged: (value) {
//             setState(() => activeFilter.selectedCustomer = value);
//           },
//         );
//       },
//     );
//   }
//
// // _buildInstrumentFilter anpassen
//   Widget _buildInstrumentFilter() {
//     return StreamBuilder<QuerySnapshot>(
//       stream: FirebaseFirestore.instance
//           .collection('instruments')
//           .orderBy('name')
//           .snapshots(),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) return const SizedBox();
//
//         return DropdownButtonFormField<String>(
//           decoration: const InputDecoration(
//             labelText: 'Instrument',
//             border: OutlineInputBorder(),
//           ),
//           value: activeFilter.selectedInstrument,
//           items: [
//             const DropdownMenuItem<String>(
//               value: null,
//               child: Text('Alle Instrumente'),
//             ),
//             ...snapshot.data!.docs.map((doc) {
//               final data = doc.data() as Map<String, dynamic>;
//               return DropdownMenuItem<String>(
//                 value: doc.id,
//                 child: Text(data['name'] ?? ''),
//               );
//             }).toList(),
//           ],
//           onChanged: (value) {
//             setState(() => activeFilter.selectedInstrument = value);
//           },
//         );
//       },
//     );
//   }
//   Widget _buildActiveFiltersChips() {
//     return SingleChildScrollView(
//       scrollDirection: Axis.horizontal,
//       padding: const EdgeInsets.all(8),
//       child: Row(
//         children: [
//           // Datumsfilter - Startdatum
//           if (activeFilter.startDate != null)
//             Padding(
//               padding: const EdgeInsets.only(right: 8),
//               child: Chip(
//                 label: Text('Von: ${DateFormat('dd.MM.yyyy').format(activeFilter.startDate!)}'),
//                 deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
//                 onDeleted: () {
//                   setState(() {
//                     activeFilter.startDate = null;
//                   });
//                 },
//               ),
//             ),
//
//           // Datumsfilter - Enddatum
//           if (activeFilter.endDate != null)
//             Padding(
//               padding: const EdgeInsets.only(right: 8),
//               child: Chip(
//                 label: Text('Bis: ${DateFormat('dd.MM.yyyy').format(activeFilter.endDate!)}'),
//                 deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
//                 onDeleted: () {
//                   setState(() {
//                     activeFilter.endDate = null;
//                   });
//                 },
//               ),
//             ),
//
//           // Betragsfilter - Mindestbetrag
//           if (activeFilter.minAmount != null)
//             Padding(
//               padding: const EdgeInsets.only(right: 8),
//               child: Chip(
//                 label: Text('Min: ${activeFilter.minAmount!.toStringAsFixed(2)} CHF'),
//                 deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
//                 onDeleted: () {
//                   setState(() {
//                     activeFilter.minAmount = null;
//                   });
//                 },
//               ),
//             ),
//
//           // Betragsfilter - Höchstbetrag
//           if (activeFilter.maxAmount != null)
//             Padding(
//               padding: const EdgeInsets.only(right: 8),
//               child: Chip(
//                 label: Text('Max: ${activeFilter.maxAmount!.toStringAsFixed(2)} CHF'),
//                 deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
//                 onDeleted: () {
//                   setState(() {
//                     activeFilter.maxAmount = null;
//                   });
//                 },
//               ),
//             ),
//
//           // Kundenfilter
//           if (activeFilter.selectedCustomer != null)
//             StreamBuilder<DocumentSnapshot>(
//               stream: FirebaseFirestore.instance
//                   .collection('customers')
//                   .doc(activeFilter.selectedCustomer)
//                   .snapshots(),
//               builder: (context, snapshot) {
//                 if (!snapshot.hasData) return const SizedBox();
//                 final customerData = snapshot.data?.data() as Map<String, dynamic>?;
//                 if (customerData == null) return const SizedBox();
//
//                 return Padding(
//                   padding: const EdgeInsets.only(right: 8),
//                   child: Chip(
//                     label: Text('Kunde: ${customerData['company']}'),
//                     deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
//                     onDeleted: () {
//                       setState(() {
//                         activeFilter.selectedCustomer = null;
//                       });
//                     },
//                   ),
//                 );
//               },
//             ),
//
//           // Instrumentenfilter
//           if (activeFilter.selectedInstrument != null)
//             StreamBuilder<DocumentSnapshot>(
//               stream: FirebaseFirestore.instance
//                   .collection('instruments')
//                   .doc(activeFilter.selectedInstrument)
//                   .snapshots(),
//               builder: (context, snapshot) {
//                 if (!snapshot.hasData) return const SizedBox();
//                 final instrumentData = snapshot.data?.data() as Map<String, dynamic>?;
//                 if (instrumentData == null) return const SizedBox();
//
//                 return Padding(
//                   padding: const EdgeInsets.only(right: 8),
//                   child: Chip(
//                     label: Text('Instrument: ${instrumentData['name']}'),
//                     deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
//                     onDeleted: () {
//                       setState(() {
//                         activeFilter.selectedInstrument = null;
//                       });
//                     },
//                   ),
//                 );
//               },
//             ),
//
//           // Messefilter
//           if (activeFilter.selectedFair != null)
//             StreamBuilder<DocumentSnapshot>(
//               stream: FirebaseFirestore.instance
//                   .collection('fairs')
//                   .doc(activeFilter.selectedFair)
//                   .snapshots(),
//               builder: (context, snapshot) {
//                 if (!snapshot.hasData) return const SizedBox();
//                 final fairData = snapshot.data?.data() as Map<String, dynamic>?;
//                 if (fairData == null) return const SizedBox();
//
//                 return Padding(
//                   padding: const EdgeInsets.only(right: 8),
//                   child: Chip(
//                     label: Text('Messe: ${fairData['name']}'),
//                     deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
//                     onDeleted: () {
//                       setState(() {
//                         activeFilter.selectedFair = null;
//                       });
//                     },
//                   ),
//                 );
//               },
//             ),
//
//           // Produktfilter
//           if (activeFilter.selectedProduct != null)
//             StreamBuilder<DocumentSnapshot>(
//               stream: FirebaseFirestore.instance
//                   .collection('inventory')
//                   .doc(activeFilter.selectedProduct)
//                   .snapshots(),
//               builder: (context, snapshot) {
//                 if (!snapshot.hasData) return const SizedBox();
//                 final productData = snapshot.data?.data() as Map<String, dynamic>?;
//                 if (productData == null) return const SizedBox();
//
//                 return Padding(
//                   padding: const EdgeInsets.only(right: 8),
//                   child: Chip(
//                     label: Text('Artikel: ${productData['product_name']}'),
//                     deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
//                     onDeleted: () {
//                       setState(() {
//                         activeFilter.selectedProduct = null;
//                       });
//                     },
//                   ),
//                 );
//               },
//             ),
//
//           // Reset-Button, wenn mindestens ein Filter aktiv ist
//           if (_hasActiveFilters())
//             Padding(
//               padding: const EdgeInsets.only(right: 8),
//               child: Chip(
//                 label: const Text('Alle Filter zurücksetzen'),
//                 deleteIcon:   getAdaptiveIcon(iconName: 'refresh', defaultIcon: Icons.refresh,size: 18),
//                 onDeleted: () {
//                   setState(() {
//                     activeFilter = SalesFilter();
//                   });
//                 },
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//   Widget _buildSalesList() {
//     return StreamBuilder<QuerySnapshot>(
//       stream: _buildQuery().snapshots(),
//       builder: (context, snapshot) {
//         if (snapshot.hasError) {
//           return Center(
//             child: Text('Fehler: ${snapshot.error}'),
//           );
//         }
//
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Center(child: CircularProgressIndicator());
//         }
//
//         final docs = snapshot.data?.docs ?? [];
//
//         if (docs.isEmpty) {
//           return const Center(
//             child: Text('Keine Verkäufe gefunden'),
//           );
//         }
//
//         return ListView.builder(
//           itemCount: docs.length,
//           padding: const EdgeInsets.all(16),
//           itemBuilder: (context, index) {
//             final doc = docs[index];
//             final data = doc.data() as Map<String, dynamic>;
//             final customer = data['customer'] as Map<String, dynamic>;
//             final items = (data['items'] as List).cast<Map<String, dynamic>>();
//             final metadata = data['metadata'] as Map<String, dynamic>;
//             final calculations = data['calculations'] as Map<String, dynamic>;
//             final timestamp = getDateTimeFromTimestamp(metadata['timestamp']);
//
//             return Card(
//               child: ListTile(
//                 title: Row(
//                   children: [
//                     Expanded(
//                       child: Text(
//                         customer['company'] ?? 'Unbekannter Kunde',
//                         style: const TextStyle(fontWeight: FontWeight.bold),
//                       ),
//                     ),
//                     Text(
//                       '${(calculations['total'] ?? 0.0).toStringAsFixed(2)} CHF',
//                       style: const TextStyle(fontWeight: FontWeight.bold),
//                     ),
//                   ],
//                 ),
//                 subtitle: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text('Datum: ${DateFormat('dd.MM.yyyy').format(timestamp)}'),
//                     Text('Artikel: ${items.length}'),
//                   ],
//                 ),
//                 onTap: () => _showSaleDetails(doc.id, data),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
//   Query<Map<String, dynamic>> _buildQuery() {
//     Query<Map<String, dynamic>> query = FirebaseFirestore.instance
//         .collection('sales_receipts');
//
//     // Datum und Summe Filter
//     if (activeFilter.startDate != null) {
//       query = query.where('metadata.timestamp',
//           isGreaterThanOrEqualTo: Timestamp.fromDate(activeFilter.startDate!));
//     }
//     if (activeFilter.endDate != null) {
//       query = query.where('metadata.timestamp',
//           isLessThanOrEqualTo: Timestamp.fromDate(
//               DateTime(activeFilter.endDate!.year,
//                   activeFilter.endDate!.month,
//                   activeFilter.endDate!.day, 23, 59, 59)
//           ));
//     }
//     if (activeFilter.minAmount != null) {
//       query = query.where('calculations.total',
//           isGreaterThanOrEqualTo: activeFilter.minAmount);
//     }
//     if (activeFilter.maxAmount != null) {
//       query = query.where('calculations.total',
//           isLessThanOrEqualTo: activeFilter.maxAmount);
//     }
//
//     // Korrigierter Messefilter
//     if (activeFilter.selectedFair != null) {
//       query = query.where('metadata.fairId', isEqualTo: activeFilter.selectedFair);
//     }
//
//     // Produktfilter
//     if (activeFilter.selectedProduct != null) {
//       query = query.where('items.product_id', arrayContains: activeFilter.selectedProduct);
//     }
//
//     // Am Ende sortieren
//     query = query.orderBy('metadata.timestamp', descending: true);
//
//     return query;
//   }
//
//
// // Erweiterte Filter-Dialog Funktion
//   void _showFilterDialog() {
//     // Erstelle eine Kopie der aktuellen Filter für temporäre Änderungen
//     SalesFilter tempFilter = SalesFilter(
//       startDate: activeFilter.startDate,
//       endDate: activeFilter.endDate,
//       minAmount: activeFilter.minAmount,
//       maxAmount: activeFilter.maxAmount,
//       selectedCustomer: activeFilter.selectedCustomer,
//       selectedInstrument: activeFilter.selectedInstrument,
//     );
//
//     // Controller für die Betragsfelder
//     final minController = TextEditingController(
//       text: tempFilter.minAmount?.toString() ?? '',
//     );
//     final maxController = TextEditingController(
//       text: tempFilter.maxAmount?.toString() ?? '',
//     );
//
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return StatefulBuilder(
//           builder: (context, setState) {
//             // Hilfsfunktion für die Anzeige aktiver Filter
//             Widget buildActiveFilterInfo(String title, String? value) {
//               if (value == null || value.isEmpty) return const SizedBox.shrink();
//               return Padding(
//                 padding: const EdgeInsets.only(top: 8.0),
//                 child: Text(
//                   value,
//                   style: TextStyle(
//                     color: Theme.of(context).primaryColor,
//                     fontSize: 12,
//                   ),
//                 ),
//               );
//             }
//
//             return Dialog(
//               child: Container(
//                 width: MediaQuery.of(context).size.width * 0.9,
//                 height: MediaQuery.of(context).size.height * 0.8,
//                 padding: const EdgeInsets.all(16),
//                 child: Column(
//                   children: [
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         const Text(
//                           'Filter',
//                           style: TextStyle(
//                             fontSize: 20,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         IconButton(
//                           icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,),
//                           onPressed: () => Navigator.pop(context),
//                         ),
//                       ],
//                     ),
//                     Expanded(
//                       child: ListView(
//                         children: [
//                           // Datumsfilter
//                           Card(
//                             child: Padding(
//                               padding: const EdgeInsets.all(16.0),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   const Text(
//                                     'Zeitraum',
//                                     style: TextStyle(
//                                       fontWeight: FontWeight.bold,
//                                       fontSize: 16,
//                                     ),
//                                   ),
//                                   if (tempFilter.startDate != null || tempFilter.endDate != null)
//                                     buildActiveFilterInfo(
//                                       'Zeitraum',
//                                       'Von: ${tempFilter.startDate != null ? DateFormat('dd.MM.yyyy').format(tempFilter.startDate!) : 'Start'} '
//                                           'Bis: ${tempFilter.endDate != null ? DateFormat('dd.MM.yyyy').format(tempFilter.endDate!) : 'Ende'}',
//                                     ),
//                                   const SizedBox(height: 16),
//                                   Row(
//                                     children: [
//                                       Expanded(
//                                         child: TextButton.icon(
//                                           icon:    getAdaptiveIcon(iconName: 'calendar_today', defaultIcon: Icons.calendar_today),
//                                           label: Text(
//                                             tempFilter.startDate != null
//                                                 ? DateFormat('dd.MM.yyyy').format(tempFilter.startDate!)
//                                                 : 'Von',
//                                           ),
//                                           onPressed: () async {
//                                             final date = await showDatePicker(
//                                               context: context,
//                                               initialDate: tempFilter.startDate ?? DateTime.now(),
//                                               firstDate: DateTime(2020),
//                                               lastDate: DateTime.now(),
//                                             );
//                                             if (date != null) {
//                                               setState(() {
//                                                 tempFilter.startDate = date;
//                                               });
//                                             }
//                                           },
//                                         ),
//                                       ),
//                                       const SizedBox(width: 8),
//                                       Expanded(
//                                         child: TextButton.icon(
//                                           icon: getAdaptiveIcon(iconName: 'calendar_today', defaultIcon: Icons.calendar_today),
//                                           label: Text(
//                                             tempFilter.endDate != null
//                                                 ? DateFormat('dd.MM.yyyy').format(tempFilter.endDate!)
//                                                 : 'Bis',
//                                           ),
//                                           onPressed: () async {
//                                             final date = await showDatePicker(
//                                               context: context,
//                                               initialDate: tempFilter.endDate ?? DateTime.now(),
//                                               firstDate: DateTime(2020),
//                                               lastDate: DateTime.now(),
//                                             );
//                                             if (date != null) {
//                                               setState(() {
//                                                 tempFilter.endDate = date;
//                                               });
//                                             }
//                                           },
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                           const SizedBox(height: 16),
//                           // Betragsfilter
//                           Card(
//                             child: Padding(
//                               padding: const EdgeInsets.all(16.0),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   const Text(
//                                     'Betrag (CHF)',
//                                     style: TextStyle(
//                                       fontWeight: FontWeight.bold,
//                                       fontSize: 16,
//                                     ),
//                                   ),
//                                   if (minController.text.isNotEmpty || maxController.text.isNotEmpty)
//                                     buildActiveFilterInfo(
//                                       'Betrag',
//                                       'Von: ${minController.text.isEmpty ? "0" : minController.text} '
//                                           'Bis: ${maxController.text.isEmpty ? "∞" : maxController.text} CHF',
//                                     ),
//                                   const SizedBox(height: 16),
//                                   Row(
//                                     children: [
//                                       Expanded(
//                                         child: TextField(
//                                           controller: minController,
//                                           decoration: const InputDecoration(
//                                             labelText: 'Min',
//                                             border: OutlineInputBorder(),
//                                             suffixText: 'CHF',
//                                           ),
//                                           keyboardType: TextInputType.numberWithOptions(decimal: true),
//                                           onChanged: (value) {
//                                             setState(() {
//                                               tempFilter.minAmount = double.tryParse(value);
//                                             });
//                                           },
//                                         ),
//                                       ),
//                                       const SizedBox(width: 8),
//                                       Expanded(
//                                         child: TextField(
//                                           controller: maxController,
//                                           decoration: const InputDecoration(
//                                             labelText: 'Max',
//                                             border: OutlineInputBorder(),
//                                             suffixText: 'CHF',
//                                           ),
//                                           keyboardType: TextInputType.numberWithOptions(decimal: true),
//                                           onChanged: (value) {
//                                             setState(() {
//                                               tempFilter.maxAmount = double.tryParse(value);
//                                             });
//                                           },
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                           const SizedBox(height: 16),
//                           // Messefilter
//                           Card(
//                             child: Padding(
//                               padding: const EdgeInsets.all(16.0),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   const Text(
//                                     'Messe',
//                                     style: TextStyle(
//                                       fontWeight: FontWeight.bold,
//                                       fontSize: 16,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 16),
//                                   _buildFairFilter(),
//                                 ],
//                               ),
//                             ),
//                           ),
//                           const SizedBox(height: 16),
//                           Card(
//                             child: Padding(
//                               padding: const EdgeInsets.all(16.0),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   const Text(
//                                     'Artikel',
//                                     style: TextStyle(
//                                       fontWeight: FontWeight.bold,
//                                       fontSize: 16,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 16),
//                                   StreamBuilder<QuerySnapshot>(
//                                     stream: FirebaseFirestore.instance
//                                         .collection('inventory')
//                                         .orderBy('product_name')
//                                         .snapshots(),
//                                     builder: (context, snapshot) {
//                                       if (!snapshot.hasData) return const CircularProgressIndicator();
//
//                                       return DropdownButtonFormField<String>(
//                                         isExpanded: true, // Wichtig für die korrekte Breite
//                                         isDense: true, // Reduziert die Höhe des Buttons
//                                         menuMaxHeight: 300, // Begrenzt die Höhe des Dropdown-Menüs
//                                         decoration: const InputDecoration(
//                                           labelText: 'Artikel auswählen',
//                                           border: OutlineInputBorder(),
//                                           contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Reduzierte Polsterung
//                                         ),
//                                         value: tempFilter.selectedProduct,
//                                         items: [
//                                           const DropdownMenuItem<String>(
//                                             value: null,
//                                             child: Text(
//                                               'Alle Artikel',
//                                               overflow: TextOverflow.ellipsis, // Text abschneiden wenn zu lang
//                                             ),
//                                           ),
//                                           ...snapshot.data!.docs.map((doc) {
//                                             final data = doc.data() as Map<String, dynamic>;
//                                             return DropdownMenuItem<String>(
//                                               value: doc.id,
//                                               child: Text(
//                                                 data['product_name'] ?? '',
//                                                 overflow: TextOverflow.ellipsis, // Text abschneiden wenn zu lang
//                                               ),
//                                             );
//                                           }).toList(),
//                                         ],
//                                         onChanged: (value) {
//                                           setState(() {
//                                             tempFilter.selectedProduct = value;
//                                           });
//                                         },
//                                       );
//                                     },
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           )
//                         ],
//                       ),
//                     ),
//                     ButtonBar(
//                       children: [
//                         TextButton(
//                           onPressed: () {
//                             setState(() {
//                               tempFilter = SalesFilter();
//                               minController.clear();
//                               maxController.clear();
//                             });
//                           },
//                           child: const Text('Zurücksetzen'),
//                         ),
//                         ElevatedButton(
//                           onPressed: () {
//                             this.setState(() {
//                               activeFilter = tempFilter;
//                             });
//                             Navigator.pop(context);
//                           },
//                           child: const Text('Anwenden'),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
//   DateTime getDateTimeFromTimestamp(dynamic timestamp) {
//     if (timestamp == null) return DateTime.now();
//     if (timestamp is Timestamp) return timestamp.toDate();
//     if (timestamp is DateTime) return timestamp;
//     if (timestamp is String) return DateTime.parse(timestamp);
//     return DateTime.now();
//   }
//   void _showSaleDetails(String receiptId, Map<String, dynamic> data) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         final customer = data['customer'] as Map<String, dynamic>;
//         final items = (data['items'] as List).cast<Map<String, dynamic>>();
//         final metadata = data['metadata'] as Map<String, dynamic>;
//         final calculations = data['calculations'] as Map<String, dynamic>;
//         final timestamp = getDateTimeFromTimestamp(metadata['timestamp']);
//
//         return Dialog(
//           backgroundColor: Colors.white,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: Container(
//             width: MediaQuery.of(context).size.width * 0.9,
//             height: MediaQuery.of(context).size.height * 0.8,
//             padding: const EdgeInsets.all(24),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // Header mit Beleg-Nr und Schließen-Button
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           'Verkaufsdetails',
//                           style: TextStyle(
//                             fontSize: 20,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         Text(
//                           'Nr. $receiptId',
//                           style: TextStyle(
//                             color: Colors.grey[600],
//                             fontSize: 14,
//                           ),
//                         ),
//                       ],
//                     ),
//                     IconButton(
//                       icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,),
//                       onPressed: () => Navigator.pop(context),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 16),
//
//                 // Kunde und Datum in einer Zeile
//                 Row(
//                   children: [
//                     // Kundeninfo
//                     Expanded(
//                       flex: 3,
//                       child: Card(
//                         child: Padding(
//                           padding: const EdgeInsets.all(12),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Row(
//                                 children: [
//                                   getAdaptiveIcon(iconName: 'business', defaultIcon: Icons.business,
//                                       size: 16,
//                                       color: Theme.of(context).primaryColor),
//                                   const SizedBox(width: 8),
//                                   const Text('Kunde',
//                                       style: TextStyle(
//                                         fontSize: 14,
//                                         fontWeight: FontWeight.bold,
//                                       )),
//                                 ],
//                               ),
//                               const SizedBox(height: 8),
//                               Text(
//                                 customer['company'] ?? '',
//                                 style: const TextStyle(fontSize: 13),
//                               ),
//                               Text(
//                                 customer['fullName'] ?? '',
//                                 style: TextStyle(
//                                   fontSize: 12,
//                                   color: Colors.grey[600],
//                                 ),
//                               ),
//                               Text(
//                                 customer['address'] ?? '',
//                                 style: TextStyle(
//                                   fontSize: 12,
//                                   color: Colors.grey[600],
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     // Datum
//                     Expanded(
//                       flex: 2,
//                       child: Card(
//                         child: Padding(
//                           padding: const EdgeInsets.all(12),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Row(
//                                 children: [
//
//                                   getAdaptiveIcon(iconName: 'calendar_today', defaultIcon: Icons.calendar_today,size: 16,
//                                       color: Theme.of(context).primaryColor),
//                                   const SizedBox(width: 8),
//                                   const Text('Datum',
//                                       style: TextStyle(
//                                         fontSize: 14,
//                                         fontWeight: FontWeight.bold,
//                                       )),
//                                 ],
//                               ),
//                               const SizedBox(height: 8),
//                               Text(
//                                 DateFormat('dd.MM.yyyy').format(timestamp),
//                                 style: const TextStyle(fontSize: 13),
//                               ),
//                               Text(
//                                 DateFormat('HH:mm').format(timestamp),
//                                 style: TextStyle(
//                                   fontSize: 12,
//                                   color: Colors.grey[600],
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 16),
//
//                 // Artikelliste
//                 Expanded(
//                   child: Card(
//                     child: Padding(
//                       padding: const EdgeInsets.all(16),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           // Artikellisten-Header
//                           Row(
//                             children: [
//                                getAdaptiveIcon(iconName: 'shopping_cart', defaultIcon: Icons.shopping_cart, size: 16),
//                               const SizedBox(width: 8),
//                               Text(
//                                 'Artikel (${items.length})',
//                                 style: const TextStyle(
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: 16),
//
//                           // Spaltentitel
//                           Container(
//                             padding: const EdgeInsets.symmetric(vertical: 8),
//                             decoration: BoxDecoration(
//                               border: Border(
//                                 bottom: BorderSide(color: Colors.grey.shade300),
//                               ),
//                             ),
//                             child: const Row(
//                               children: [
//                                 Expanded(flex: 3, child: Text('Produkt', style: TextStyle(fontWeight: FontWeight.bold))),
//                                 Expanded(child: Text('Anz.', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
//                                 Expanded(flex: 3, child: Text('Preis', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
//                               ],
//                             ),
//                           ),
//
//                           // Artikelliste
//                           Expanded(
//                             child: ListView.builder(
//                               itemCount: items.length,
//                               itemBuilder: (context, index) {
//                                 final item = items[index];
//                                 final quantity = item['quantity'] as double;
//                                 final pricePerUnit = item['price_per_unit'] as double;
//                                 final subtotal = quantity * pricePerUnit;
//                                 final discount = item['discount'] as Map<String, dynamic>?;
//                                 final discountAmount = item['discount_amount'] as double? ?? 0.0;
//                                 final total = item['total'] as double? ?? subtotal;
//
//                                 return Container(
//                                   padding: const EdgeInsets.symmetric(vertical: 12),
//                                   decoration: BoxDecoration(
//                                     border: Border(
//                                       bottom: BorderSide(color: Colors.grey.shade200),
//                                     ),
//                                   ),
//                                   child: Row(
//                                     crossAxisAlignment: CrossAxisAlignment.start,
//                                     children: [
//                                       // Produktinfo
//                                       Expanded(
//                                         flex: 3,
//                                         child: Column(
//                                           crossAxisAlignment: CrossAxisAlignment.start,
//                                           children: [
//                                             Text(
//                                               item['product_name'] ?? '',
//                                               style: const TextStyle(fontWeight: FontWeight.w500),
//                                             ),
//                                             const SizedBox(height: 2),
//
//                                             Text(
//                                               ' ${item['quality_name']}',
//                                               style: TextStyle(
//                                                 color: Colors.grey[600],
//                                                 fontSize: 12,
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                       // Menge
//                                       Expanded(
//                                         child: Text(
//                                           '$quantity',
//                                           textAlign: TextAlign.center,
//                                         ),
//                                       ),
//                                       // Preis und Rabatt
//                                       Expanded(
//                                         flex: 3,
//                                         child: Column(
//                                           crossAxisAlignment: CrossAxisAlignment.end,
//                                           children: [
//                                             Text(
//                                               '${pricePerUnit.toStringAsFixed(2)} CHF/${item['unit']}',
//                                               style: TextStyle(
//                                                 color: Colors.grey[600],
//                                                 fontSize: 12,
//                                               ),
//                                             ),
//                                             Text(
//                                               '${subtotal.toStringAsFixed(2)} CHF',
//                                               style: TextStyle(
//                                                 decoration: discountAmount > 0 ? TextDecoration.lineThrough : null,
//                                                 color: discountAmount > 0 ? Colors.grey : null,
//                                                 fontSize: 13,
//                                               ),
//                                             ),
//                                             if (discountAmount > 0) ...[
//                                               if (discount?['percentage'] != null && discount!['percentage'] > 0)
//                                                 Text(
//                                                   '- ${discount['percentage']}%',
//                                                   style: TextStyle(
//                                                     color: Theme.of(context).colorScheme.error,
//                                                     fontSize: 12,
//                                                   ),
//                                                 ),
//                                               Text(
//                                                 '- ${discountAmount.toStringAsFixed(2)} CHF',
//                                                 style: TextStyle(
//                                                   color: Theme.of(context).colorScheme.error,
//                                                   fontSize: 12,
//                                                 ),
//                                               ),
//                                               Text(
//                                                 '${total.toStringAsFixed(2)} CHF',
//                                                 style: const TextStyle(
//                                                   fontWeight: FontWeight.bold,
//                                                   fontSize: 13,
//                                                 ),
//                                               ),
//                                             ],
//                                           ],
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 );
//                               },
//                             ),
//                           ),
//
//                           // Summenbereich
//                           Container(
//                             padding: const EdgeInsets.all(16),
//                             decoration: BoxDecoration(
//                               border: Border(
//                                 top: BorderSide(color: Colors.grey.shade300),
//                               ),
//                             ),
//                             child: Column(
//                               children: [
//                                 Row(
//                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                   children: [
//                                     Text('Zwischensumme:', style: TextStyle(color: Colors.grey[600])),
//                                     Text(
//                                       '${calculations['subtotal'].toStringAsFixed(2)} CHF',
//                                       style: TextStyle(color: Colors.grey[600]),
//                                     ),
//                                   ],
//                                 ),
//                                 if ((calculations['item_discounts'] as double? ?? 0.0) > 0)
//                                   Padding(
//                                     padding: const EdgeInsets.only(top: 4),
//                                     child: Row(
//                                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                       children: [
//                                         Text(
//                                           'Positionsrabatte:',
//                                           style: TextStyle(color: Theme.of(context).colorScheme.error),
//                                         ),
//                                         Text(
//                                           '- ${calculations['item_discounts'].toStringAsFixed(2)} CHF',
//                                           style: TextStyle(color: Theme.of(context).colorScheme.error),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 if ((calculations['total_discount_amount'] as double? ?? 0.0) > 0)
//                                   Padding(
//                                     padding: const EdgeInsets.only(top: 4),
//                                     child: Row(
//                                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                       children: [
//                                         Text(
//                                           'Gesamtrabatt:',
//                                           style: TextStyle(color: Theme.of(context).colorScheme.error),
//                                         ),
//                                         Text(
//                                           '- ${calculations['total_discount_amount'].toStringAsFixed(2)} CHF',
//                                           style: TextStyle(color: Theme.of(context).colorScheme.error),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 Padding(
//                                   padding: const EdgeInsets.only(top: 4),
//                                   child: Row(
//                                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                     children: [
//                                       const Text('Nettobetrag:'),
//                                       Text('${calculations['net_amount'].toStringAsFixed(2)} CHF'),
//                                     ],
//                                   ),
//                                 ),
//                                 Padding(
//                                   padding: const EdgeInsets.only(top: 4),
//                                   child: Row(
//                                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                     children: [
//                                       Text('MwSt (${calculations['vat_rate'].toStringAsFixed(1)}%):'),
//                                       Text('${calculations['vat_amount'].toStringAsFixed(2)} CHF'),
//                                     ],
//                                   ),
//                                 ),
//                                 const Divider(height: 16),
//                                 Row(
//                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                   children: [
//                                     const Text(
//                                       'Gesamtbetrag:',
//                                       style: TextStyle(fontWeight: FontWeight.bold),
//                                     ),
//                                     Text(
//                                       '${calculations['total'].toStringAsFixed(2)} CHF',
//                                       style: const TextStyle(fontWeight: FontWeight.bold),
//                                     ),
//                                   ],
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//
//                 // Aktionen
//                 const SizedBox(height: 16),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     ElevatedButton.icon(
//                       icon: getAdaptiveIcon(iconName: 'share', defaultIcon: Icons.share),
//                       label: const Text('PDF Beleg'),
//                       onPressed: () async {
//                         await _shareReceipt(receiptId, data['pdf_url']);
//                         Navigator.pop(context);
//                       },
//                     ),
//                     const SizedBox(width: 16),  // Abstand zwischen den Buttons
//                     if (data['csv_url'] != null)  // Nur anzeigen wenn CSV verfügbar
//                       ElevatedButton.icon(
//                         icon:  getAdaptiveIcon(iconName: 'table_chart', defaultIcon: Icons.table_chart, color: Colors.blue),
//                         label: const Text('CSV Export'),
//                         onPressed: () async {
//                           await _shareReceipt(receiptId, data['csv_url']);
//                           Navigator.pop(context);
//                         },
//                       ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//
//
//   Widget _buildDetailSection(String title, List<Widget> children) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           title,
//           style: const TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         const SizedBox(height: 8),
//         ...children,
//         const SizedBox(height: 16),
//       ],
//     );
//   }
//
//   Future<void> _sendReceiptEmail(String receiptId, String pdfUrl, String recipientEmail) async {
//     try {
//       // PDF herunterladen
//       final response = await http.get(Uri.parse(pdfUrl));
//       if (response.statusCode != 200) {
//         throw 'Fehler beim Laden der PDF';
//       }
//
//       // Temporäre Datei erstellen
//       final tempDir = await getTemporaryDirectory();
//       final tempFile = File('${tempDir.path}/Lieferschein_$receiptId.pdf');
//       await tempFile.writeAsBytes(response.bodyBytes);
//
//       // E-Mail vorbereiten
//       final Uri emailUri = Uri(
//         scheme: 'mailto',
//         path: recipientEmail,
//         query: _encodeQueryParameters({
//           'subject': 'Lieferschein Nr. $receiptId',
//           'body': 'Anbei finden Sie Ihren Lieferschein.\n\nMit freundlichen Grüßen',
//         }),
//       );
//
//       if (await canLaunchUrl(emailUri)) {
//         await launchUrl(emailUri);
//       }
//
//       // Temporäre Datei nach 5 Minuten löschen
//       Future.delayed(const Duration(minutes: 5), () async {
//         if (await tempFile.exists()) {
//           await tempFile.delete();
//         }
//       });
//
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Fehler: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }
//
//   Future<void> _shareReceipt(String receiptId, String pdfUrl) async {
//     try {
//       // PDF herunterladen
//       final response = await http.get(Uri.parse(pdfUrl));
//       if (response.statusCode != 200) {
//         throw 'Fehler beim Laden der PDF';
//       }
//
//       // Temporäre Datei erstellen
//       final tempDir = await getTemporaryDirectory();
//       final tempFile = File('${tempDir.path}/Lieferschein_$receiptId.pdf');
//       await tempFile.writeAsBytes(response.bodyBytes);
//
//       // Datei teilen
//       await Share.shareXFiles(
//         [XFile(tempFile.path)],
//         subject: 'Lieferschein Nr. $receiptId',
//       );
//
//       // Temporäre Datei nach 5 Minuten löschen
//       Future.delayed(const Duration(minutes: 5), () async {
//         if (await tempFile.exists()) {
//           await tempFile.delete();
//         }
//       });
//
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Fehler: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }
//
//   String? _encodeQueryParameters(Map<String, String> params) {
//     return params.entries
//         .map((entry) =>
//     '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}')
//         .join('&');
//   }
//
//   bool _hasActiveFilters() {
//     return activeFilter.startDate != null ||
//         activeFilter.endDate != null ||
//         activeFilter.minAmount != null ||
//         activeFilter.maxAmount != null ||
//         activeFilter.selectedCustomer != null ||
//         activeFilter.selectedInstrument != null ||
//         activeFilter.selectedFair != null ||
//         activeFilter.selectedProduct != null;
//   }
// }