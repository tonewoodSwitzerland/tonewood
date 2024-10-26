// import 'package:flutter/material.dart';
// import '../constants.dart';
// import 'package:flutter/services.dart';
// import 'dart:math';
// import 'package:another_brother/printer_info.dart';
// import 'dart:async';
// import 'dart:typed_data';
// import 'dart:ui' as ui;
// import 'package:another_brother/custom_paper.dart';
// import 'package:another_brother/label_info.dart';
// import 'package:another_brother/printer_info.dart';
// import 'package:another_brother/type_b_printer.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:barcode_widget/barcode_widget.dart';
// import 'dart:io';
// import 'package:path_provider/path_provider.dart';
// import 'package:share_plus/share_plus.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import '../components/standard_text_field.dart';
// import 'package:fluttertoast/fluttertoast.dart';
//
// import '../printer_screen/printer_screen_settings.dart';
// import '../services/firebase_to_google_drive.dart';
// import '../services/request_permissions.dart';
//
// class PrinterScreen extends StatefulWidget {
//   const PrinterScreen({Key? key}) : super(key: key);
//
//   @override
//   PrinterScreenState createState() => PrinterScreenState();
// }
//
// class PrinterScreenState extends State<PrinterScreen> {
//
//
//
//   @override
//
//   Widget build(BuildContext context) {
//     return //MaterialApp(
//
//     //  home: PageView(children: [
//         WifiPrintPage(title: 'PJ-773 WiFi Sample');
//        // QlBluetoothPrintPage(title: 'QL-1110NWB Bluetooth Sample'),
//      // ]),
//  //   );
//   }
// }
//
// class WifiPrintPage extends StatefulWidget {
//   WifiPrintPage({Key? key, required this.title}) : super(key: key);
//
//   final String title;
//
//   @override
//
//   _WifiPrintPageState createState() => _WifiPrintPageState();
// }
//
// class _WifiPrintPageState extends State<WifiPrintPage> {
//
//   // Controller für die Textfelder (eine Liste für jede Spalte)
//   List<TextEditingController> lengthControllers = [];
//   List<TextEditingController> pieceControllers = [];
//
//   final TextEditingController _paketNrController = TextEditingController();
//   final TextEditingController _holzartController = TextEditingController();
//   bool _error = false;
//
//   Printer? _selectedPrinter;
//   bool _isPrinterOnline = false; // Standardmäßig offline
//   bool _printerSearching = false; // Status der Druckersuche
//   Color _indicatorColor = Colors.orange; // Startfarbe der Leuchte
//   String _individualInput = '';
//
//
// bool isLoading=true;
//   List<String> customers = [];
//   bool isLoadingCustomers = true; // Verfolgt, ob die Kundenliste geladen wird
//
// // Hier wird initState hinzugefügt
//   @override
//   void initState() {
//     super.initState();
//     // Überprüfe den Druckerstatus direkt beim Laden der Seite
//     _checkPrinterStatus();
//     _initializeControllers();
//     _loadBarcodeFromFirestore();
//     _loadCustomersFromFirestore();
//   }
//
//   // Funktion zum Laden der Kunden aus Firestore
//   Future<void> _loadCustomersFromFirestore() async {
//     try {
//       QuerySnapshot snapshot = await FirebaseFirestore.instance
//           .collection('companies')
//           .doc('100')
//           .collection('customers')
//           .get();
//
//       // Extrahiere die Kundennamen aus dem Snapshot
//       List<String> loadedCustomers = snapshot.docs
//           .map((doc) => doc['name'].toString())
//           .toList();
//
//       setState(() {
//         customers = loadedCustomers;
//         isLoadingCustomers = false; // Ladezustand beenden
//       });
//     } catch (e) {
//       // Optional: Fehlerbehandlung
//       print("Fehler beim Laden der Kunden: $e");
//       setState(() {
//         isLoadingCustomers = false; // Ladezustand beenden, auch bei Fehlern
//       });
//     }
//   }
//
//
//
//   // Funktion zum Abrufen des Barcode-Werts aus Firebase
//   Future<void> _loadBarcodeFromFirestore() async {
//     int barcodeInt=0;
//     try {
//       // Hole das Dokument aus Firestore
//       DocumentSnapshot document = await FirebaseFirestore.instance
//           .collection('companies')
//           .doc('100')
//           .get();
//
//       // Überprüfen, ob das Feld existiert und setze den Barcode-Wert
//       if (document.exists && document['letztesHobelPaket'] != null) {
//         setState(() {
//           clearPrinterValuesAfterInput=document['clearPrinterValuesAfterInput'];
//           // Aktualisiere den Barcode mit dem geladenen Wert aus Firestore
//           barcodeInt=document['letztesHobelPaket']+1;
//           barcodeData = barcodeInt.toString().padLeft(8, '0');
//           isLoading = false;
//         });
//       } else {
//         // Optional: Fehlerbehandlung, falls das Feld nicht gefunden wird
//         print("Das Feld 'letztesHobelPaket' wurde nicht gefunden.");
//         isLoading = false;
//       }
//     } catch (e) {
//       // Optional: Fehlerbehandlung bei Firestore-Fehlern
//       print("Fehler beim Abrufen des Barcodes: $e");
//       isLoading = false;
//     }
//   }
//   void _initializeControllers() {
//     // Erstelle TextEditingController für jede Zeile in der Tabelle
//     lengthControllers = List.generate(tableRows.length, (index) {
//       return TextEditingController(text: tableRows[index]['Länge']);
//     });
//     pieceControllers = List.generate(tableRows.length, (index) {
//       return TextEditingController(text: tableRows[index]['Stück']);
//     });
//   }
//
//   Future<void> _exportToDatabase() async {
//
//     print("xe");
//     try {
//       // Referenz zur "planer_packages"-Collection mit der Barcode-ID
//       DocumentReference packageDocRef = FirebaseFirestore.instance.collection('companies').doc('100').collection('planer_packages').doc(barcodeData); // Verwende den Barcode als Dokument-ID
//
//       // Hinzufügen des Hauptdokuments mit den Werten, die keine Liste sind (z.B. Auftragsnr, Kunde etc.)
//       await packageDocRef.set({
//         'Auftragsnr': selectedAuftragsNrPaketZettelHobeln,
//         'Barcode': barcodeData,
//         'Bemerkung': selectedBemerkungPaketZettelHobeln,
//         'Kommission': selectedKommissionPaketZettelHobeln,
//         'Kunde': selectedFirmaPaketZettelHobeln,
//         'Id10':  '',
//         'Id11':  '',
//         'Id12':  '',
//         'Id13':  '',
//         'Id14':  '',
//         'Id15':  '',
//         'Id16':  '',
//         'Id17':  '',
//         'Id18':  '',
//         'Id19':  '',
//
//       }, SetOptions(merge: true));
//
//       // Referenz zur "positions"-Unter-Collection des Hauptdokuments
//       CollectionReference positionsCollectionRef = packageDocRef.collection('positions');
//
//       // Durchlaufen der Zeilen der Tabelle und Speichern der Werte in der Unter-Collection "positions"
//       for (int index = 0; index < tableRows.length; index++) {
//         Map<String, dynamic> row = tableRows[index];
//
//         // Hinzufügen jeder Zeile in die "positions"-Unter-Collection mit der Zeilennummer als Dokument-ID
//         await positionsCollectionRef.doc((index + 1).toString()).set({
//           'B': row['Breite'] ?? 0,
//           'H': row['Höhe'] ?? 0,
//           'L': row['Länge'] ?? 0,
//           'Menge': row['Menge'] ?? 0,
//           'Stk': row['Stück'] ?? 0,
//           'Id100':  '',
//           'Id101':  '',
//           'Id102':  '',
//           'Id103':  '',
//           'Id104':  '',
//           'Id105':  '',
//           'Id106':  '',
//           'Id107':  '',
//           'Id108':  '',
//           'Id109':  '',
//         }, SetOptions(merge: true));
//       }
//
//       print("Datenbankexport erfolgreich");
//     } catch (e) {
//       print("Fehler beim Export der Datenbank: $e");
//     }
//   }
//
//   Future<void>  printLabel(BuildContext context) async {
//
//     var printer = Printer();
//     var printInfo = PrinterInfo();
//     printInfo.printerModel = Model.QL_1110NWB;
//     printInfo.printMode = PrintMode.FIT_TO_PAGE;
//     printInfo.isAutoCut = true;
//     printInfo.port = Port.NET;
//     printInfo.printQuality = PrintQuality.HIGH_RESOLUTION;
//     // Set the label type.
//     printInfo.labelNameIndex = QL1100.ordinalFromID(QL1100.W103.getId());
//
//     // Set the printer info so we can use the SDK to get the printers.
//     await printer.setPrinterInfo(printInfo);
//
//     // Get a list of printers with my model available in the network.
//     List<NetPrinter> printers = await printer.getNetPrinters([Model.QL_1110NWB.getName()]);
//
//     if (printers.isEmpty) {
//       AppToast.show(message:"Drucker nicht gefunden",height:h);
//
//       return;
//     }
//
//     // Get the IP Address from the first printer found.
//     printInfo.ipAddress = printers.single.ipAddress;
//     printer.setPrinterInfo(printInfo);
//     printInfo.printQuality = PrintQuality.HIGH_RESOLUTION;
//     // Generiere das PDF und drucke es anschließend
//     final pdfFile = await _generatePdf();
//     final pdfFileForPrinter = await _generatePdfForPrinter();
//     Uint8List pdfBytes = await pdfFile.readAsBytes();
//     await uploadPlanerPackagePDFFileToGoogleDrive(barcodeData, pdfBytes);
//
//
//     printer.printPdfFile(pdfFileForPrinter.path,1);
//   }
//
//
//   Future<void> showSingleInputDialog(BuildContext context,bool onlyNumbers,int maxLines,String hintText, String headline, String initialNr,  {Function(String nr)? onSave}) async {
//     TextEditingController nrController = TextEditingController(text: initialNr);
//
//     await showDialog(
//       context: context,
//       barrierDismissible: false, // Verhindert, dass der Dialog durch Klick außerhalb geschlossen wird
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text(headline, style:  smallHeadline4_0),
//           content:
//               Expanded(
//                 child: TextField(
//                   maxLines: maxLines,
//                   controller: nrController,
//                   keyboardType: onlyNumbers?TextInputType.number:TextInputType.text, // Nur Zahlen
//
//                   decoration: InputDecoration(hintText: hintText),
//                 ),
//               ),
//
//
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop(); // Dialog schließen
//               },
//               child: const Text('Abbrechen', style: smallHeadline4_0),
//             ),
//             TextButton(
//               onPressed: () {
//                 if (onSave != null) {
//                   onSave(nrController.text); // Speichert Breite und Höhe
//                 }
//                 Navigator.of(context).pop(); // Dialog schließen
//               },
//               child: const Text('Speichern', style: smallHeadline4_0),
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//
//   Future<void> showAbmessungDialog(BuildContext context, int i, String initialWidth, String initialHeight, {Function(String width, String height)? onSave}) async {
//     TextEditingController widthController = TextEditingController(text: initialWidth);
//     TextEditingController heightController = TextEditingController(text: initialHeight);
//
//     await showDialog(
//       context: context,
//       barrierDismissible: false, // Verhindert, dass der Dialog durch Klick außerhalb geschlossen wird
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Maße eingeben', style:  smallHeadline4_0),
//           content: Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               // TextField für Breite
//               Expanded(
//                 child: TextField(
//                   controller: widthController,
//                   keyboardType: TextInputType.number, // Nur Zahlen
//                   inputFormatters: <TextInputFormatter>[
//                     FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')), // Erlaubt nur Zahlen und den Punkt als Dezimaltrennzeichen
//
//                   ],
//                   decoration: InputDecoration(hintText: 'Breite (mm)'),
//                 ),
//               ),
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 8.0),
//                 child: Text('x', style: TextStyle(fontSize: 18)), // Das 'x' zwischen den Feldern
//               ),
//               // TextField für Höhe
//               Expanded(
//                 child: TextField(
//                   controller: heightController,
//                   keyboardType: TextInputType.number, // Nur Zahlen
//                   inputFormatters: <TextInputFormatter>[
//                     FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')), // Erlaubt nur Zahlen und den Punkt als Dezimaltrennzeichen
//
//                   ],
//                   decoration: InputDecoration(hintText: 'Höhe (mm)'),
//                 ),
//               ),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop(); // Dialog schließen
//               },
//               child: const Text('Abbrechen'),
//             ),
//             TextButton(
//               onPressed: () {
//                 if (onSave != null) {
//                   onSave(widthController.text, heightController.text); // Speichert Breite und Höhe
//                 }
//                 Navigator.of(context).pop(); // Dialog schließen
//               },
//               child: const Text('Speichern'),
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   void _addRow() {
//     setState(() {
//       tableRows.insert(0, {'Abmessung': '', 'Länge': '', 'Stück': ''});
//
//       // Füge die neuen Controller ebenfalls an Position 1 hinzu
//       lengthControllers.insert(0, TextEditingController());
//       pieceControllers.insert(0, TextEditingController());
//     });
//   }
//
//   void _removeRow(int index) {
//     setState(() {
//       tableRows.removeAt(index);
//       lengthControllers.removeAt(index);
//       pieceControllers.removeAt(index);
//     });
//   }
//
//
//   // Funktion zum Neuordnen der Reihen
//   void _reorderRows(int oldIndex, int newIndex) {
//     setState(() {
//       if (newIndex > oldIndex) {
//         newIndex -= 1;
//       }
//       final row = tableRows.removeAt(oldIndex);
//       tableRows.insert(newIndex, row);
//     });
//   }
//
//   Widget _buildTable() {
//     return Column(
//       children: [
//         Padding(
//           padding: const EdgeInsets.symmetric(vertical: 8.0),
//           child: Row(
//             children: [
//               Expanded(flex: 6, child: Text('Maße [mm x mm]', style: smallHeadline)),
//               Expanded(flex: 4, child: Text('Länge [m]', style: smallHeadline)),
//               Expanded(flex: 4, child: Text('Stück', style: smallHeadline)),
//               ElevatedButton(
//                 child: Icon(Icons.add, color: goldenColour, size: 30),
//                 onPressed: _addRow,
//               ),
//             ],
//           ),
//         ),
//         ReorderableListView.builder(
//           shrinkWrap: true,
//           physics: NeverScrollableScrollPhysics(),
//           itemCount: tableRows.length,
//           onReorder: (int oldIndex, int newIndex) {
//             setState(() {
//               if (newIndex > oldIndex) newIndex -= 1;
//               final row = tableRows.removeAt(oldIndex);
//               tableRows.insert(newIndex, row);
//
//               final lengthController = lengthControllers.removeAt(oldIndex);
//               lengthControllers.insert(newIndex, lengthController);
//
//               final pieceController = pieceControllers.removeAt(oldIndex);
//               pieceControllers.insert(newIndex, pieceController);
//             });
//           },
//           itemBuilder: (context, index) {
//             return Container(
//               key: ValueKey(tableRows[index]),
//               margin: const EdgeInsets.symmetric(vertical: 2),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(borderRadius),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.white,
//                     offset: Offset(-1, -1),
//                     blurRadius: 1,
//                   ),
//                   BoxShadow(
//                     color: Colors.grey,
//                     offset: Offset(1, 1),
//                     blurRadius: 2,
//                   ),
//                 ],
//                 border: Border.all(color: Colors.white.withOpacity(0.2)),
//               ),
//               child: ListTile(
//                 title: Row(
//                   children: [
//                     Expanded(
//                       flex: 6,
//                       child: InkWell(
//                         onTap: () {
//                           showAbmessungDialog(
//                             context,
//                             index,
//                             tableRows[index]['Breite'] ?? '',
//                             tableRows[index]['Höhe'] ?? '',
//                             onSave: (width, height) {
//                               setState(() {
//                                 tableRows[index]['Breite'] = width;
//                                 tableRows[index]['Höhe'] = height;
//                                 tableRows[index]['Abmessung'] = '$width x $height';
//                               });
//                             },
//                           );
//                         },
//                         child: Padding(
//                           padding: const EdgeInsets.all(2.0),
//                           child: Container(
//                             alignment: Alignment.centerLeft,
//                             padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
//                             decoration: BoxDecoration(
//                                 border: Border(
//                                   bottom: BorderSide(color: Colors.black54),
//                                 )),
//                             child: Text(
//                               tableRows[index]['Abmessung'] ?? 'Abmessung',
//                               style: TextStyle(fontSize: 16),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                     Expanded(
//                       flex: 4,
//                       child: Padding(
//                         padding: const EdgeInsets.all(2.0),
//                         child: TextField(
//                           controller: lengthControllers[index],
//                           keyboardType: TextInputType.number,
//                           inputFormatters: [
//                             FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')), // Erlaubt nur Zahlen und den Punkt als Dezimaltrennzeichen
//                           ],
//                           onChanged: (value) {
//                             setState(() {
//                               tableRows[index]['Länge'] = value;
//                             });
//                           },
//                           decoration: InputDecoration(hintText: ''),
//                         ),
//                       ),
//                     ),
//                     Expanded(
//                       flex: 4,
//                       child: Padding(
//                         padding: const EdgeInsets.all(2.0),
//                         child: TextField(
//                           controller: pieceControllers[index],
//                           keyboardType: TextInputType.number,
//                           inputFormatters: [
//                             FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')), // Erlaubt nur Zahlen und den Punkt als Dezimaltrennzeichen
//                           ],
//                           onChanged: (value) {
//                             setState(() {
//                               tableRows[index]['Stück'] = value;
//                             });
//                           },
//                           decoration: InputDecoration(hintText: ''),
//                         ),
//                       ),
//                     ),
//                     IconButton(
//                       icon: Icon(Icons.delete, color: Colors.redAccent),
//                       onPressed: () {
//                         _removeRow(index);
//                       },
//                     ),
//                   ],
//                 ),
//                 trailing: ReorderableDragStartListener(
//                   index: index,
//                   child: Icon(Icons.drag_handle),
//                 ),
//               ),
//             );
//           },
//         ),
//       ],
//     );
//   }
//
//
//
//   // Funktion, um PDF herunterzuladen
//   Future<void> _downloadPdf() async {
//     totalVolume=0;
//     await requestPermissions();
//     final pdfFile = await _generatePdf();
//     final xFile = XFile(pdfFile.path);
//     Share.shareXFiles([xFile], text: 'Test');
//     // Sicherstellen, dass Berechtigungen für den Dateizugriff vorliegen
//     if (await Permission.storage.request().isGranted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text("PDF wurde gespeichert: ${pdfFile.path}"),
//         ),
//       );
//     }else{print("hell");}
//   }
//
//
//
//   Future<void> showInputDialog(
//       BuildContext context,
//       String title,
//       int maxLines,
//       bool isCustomer,
//       String? initialValue, { // initialValue ist jetzt nullable
//         Function(String)? onSave,
//       }) async {
//     TextEditingController _textController = TextEditingController(text: initialValue ?? '');
//     TextEditingController _freeTextController = TextEditingController();
//     bool isFreeTextEnabled = (initialValue?.isNotEmpty ?? false) && !isCustomer; // falls initialer Wert gesetzt ist
//     bool isLoadingCustomers = true; // Kunden werden geladen
//     List<String> customers = [];
//
//     // Funktion zum Laden der Kunden aus Firestore
//     Future<void> _loadCustomersFromFirestore() async {
//       try {
//         QuerySnapshot snapshot = await FirebaseFirestore.instance
//             .collection('companies')
//             .doc('100')
//             .collection('customers')
//             .get();
//
//         customers = snapshot.docs.map((doc) => doc['name'].toString()).toList();
//
//         // Setze den Wert für initialValue falls dieser in der Liste der Kunden enthalten ist.
//         if (!customers.contains(initialValue)) {
//           initialValue = null; // Setze auf null, falls der Wert nicht in der Liste ist.
//         }
//       } catch (e) {
//         print("Fehler beim Laden der Kunden: $e");
//       }
//
//       isLoadingCustomers = false; // Kunden sind geladen
//     }
//
//     await _loadCustomersFromFirestore(); // Kunden laden, bevor der Dialog angezeigt wird
//
//     await showDialog(
//       context: context,
//       barrierDismissible: false, // Verhindert, dass der Dialog durch Klick außerhalb geschlossen wird
//       builder: (BuildContext context) {
//         return StatefulBuilder(
//           builder: (context, setState) {
//             return AlertDialog(
//               backgroundColor: Colors.white,
//               title: Container(
//                 child: Center(
//                   child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                 ),
//               ),
//               content: SingleChildScrollView(
//                 child: Padding(
//                   padding: EdgeInsets.only(
//                     bottom: MediaQuery.of(context).viewInsets.bottom, // Anpassung an die Tastaturhöhe
//                   ),
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       // Nur bei 'Kunde' das Dropdown anzeigen
//                       if (isCustomer)
//                         Column(
//                           children: [
//                             AbsorbPointer(
//                               absorbing: isFreeTextEnabled,
//                               child: isLoadingCustomers
//                                   ? CircularProgressIndicator() // Ladeindikator während Kunden geladen werden
//                                   : DropdownButton<String>(
//                                 value: isFreeTextEnabled ? null : initialValue, // Setze den Wert nur, wenn er in der Liste ist
//                                 hint: Text("Kunde auswählen"),
//                                 items: customers.map((String customer) {
//                                   return DropdownMenuItem<String>(
//                                     value: customer,
//                                     child: Text(customer),
//                                   );
//                                 }).toList(),
//                                 onChanged: isFreeTextEnabled
//                                     ? null // Leere Funktion, wenn das Dropdown gesperrt ist
//                                     : (String? newValue) {
//                                   setState(() {
//                                     _textController.text = newValue ?? '';
//                                     initialValue = newValue; // Aktualisiere initialValue
//                                   });
//                                 },
//                               ),
//                             ),
//                             SizedBox(height: 20),
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: [
//                                 Text("ODER", style: TextStyle(fontSize: 16)),
//                               ],
//                             ),
//                           ],
//                         ),
//                       SizedBox(height: 20),
//                       if (isCustomer)
//                         Checkbox(
//                           value: isFreeTextEnabled,
//                           onChanged: (bool? value) {
//                             setState(() {
//                               isFreeTextEnabled = value!;
//                               if (!isFreeTextEnabled) {
//                                 _freeTextController.clear(); // Freitextfeld leeren, wenn der Haken entfernt wird
//                               }
//                             });
//                           },
//                         ),
//                       TextField(
//                         maxLines: maxLines,
//                         controller: _freeTextController,
//                         decoration: InputDecoration(
//                           labelText: 'Freie Eingabe',
//                         ),
//                         enabled: !isCustomer || isFreeTextEnabled, // Freitextfeld ist nur aktiv, wenn der Haken gesetzt ist
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//               actions: [
//                 TextButton(
//                   onPressed: () {
//                     Navigator.of(context).pop();
//                   },
//                   child: const Text('Abbrechen'),
//                 ),
//                 TextButton(
//                   onPressed: () {
//                     if (onSave != null) {
//                       onSave(isFreeTextEnabled ? _freeTextController.text : _textController.text); // Speichert den eingegebenen Wert
//                     }
//                     Navigator.of(context).pop();
//                   },
//                   child: const Text('Speichern'),
//                 ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }
//
//
//
//   Future<File> _generatePdfForPrinter() async {
//     final pdf = pw.Document();
//
//     // Lade das Bild-Logo aus dem Ordner 'images'
//     final ByteData logoData = await rootBundle.load('images/logo_sw.jpg');
//     final Uint8List logoBytes = logoData.buffer.asUint8List();
//     final image = pw.MemoryImage(logoBytes);
//
//     // Funktion zum Erstellen von Tabelleneinträgen ohne vertikale Linien
//     pw.TableRow _buildRow(String value, String label) {
//       return pw.TableRow(
//         children: [
//           pw.Padding(
//             padding: const pw.EdgeInsets.all(12),
//             child: pw.Container(
//               width: 110,
//               child: pw.Text(
//                 label,
//                 style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold),
//               ),
//             ),
//           ),
//           pw.Padding(
//             padding: const pw.EdgeInsets.all(12),
//             child: pw.Container(
//               width: 150,
//               child: pw.Text(
//                 value,
//                 style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold),
//               ),
//             ),
//           ),
//         ],
//       );
//     }
//     double length_bemerkung =  selectedBemerkungPaketZettelHobeln.isNotEmpty ? 100 : 0;
//     // Berechne die Gesamthöhe basierend auf der Anzahl der Tabellenzeilen
//     const double rowHeight = 40;  // Höhe jeder Zeile (z.B. 40 Punkte pro Zeile)
//     double totalHeight = 450 + (tableRows.length * rowHeight)+100+length_bemerkung; // Grundhöhe (z.B. 400) + Zeilenhöhe
//
//     // Erstelle die Seite mit der berechneten Höhe
//     pdf.addPage(
//       pw.Page(
//         pageFormat: PdfPageFormat(
//
//           marginAll: 40,
//           PdfPageFormat.a4.width, // Die Breite bleibt konstant
//           totalHeight,  // Die Höhe wird dynamisch angepasst
//         ),
//         build: (pw.Context context) => pw.Column(
//           crossAxisAlignment: pw.CrossAxisAlignment.start,
//           children: [
//             // Logo und Barcode in einer Zeile
//             pw.Row(
//               mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//               children: [
//                 pw.Image(image, width: 200, height: 100),
//                 pw.BarcodeWidget(
//                   data: barcodeData,
//                   barcode: pw.Barcode.code128(),
//                   width: 220,
//                   height: 70,
//                 ),
//               ],
//             ),
//             pw.SizedBox(height: 20),
//
//             // Tabelle für Kunde, Auftragsnr., Kommission
//             pw.Table(
//               border: pw.TableBorder(
//                 horizontalInside: pw.BorderSide(width: 2),
//               ),
//               children: [
//                 _buildRow(selectedFirmaPaketZettelHobeln.isNotEmpty ? selectedFirmaPaketZettelHobeln : '', 'Kunde'),
//                 _buildRow(selectedAuftragsNrPaketZettelHobeln.isNotEmpty ? selectedAuftragsNrPaketZettelHobeln : '', 'Auftrag'),
//                 _buildRow(selectedKommissionPaketZettelHobeln.isNotEmpty ? selectedKommissionPaketZettelHobeln : '', 'Kommission'),
//               ],
//             ),
//             pw.SizedBox(height: 20),
//
//             // Dynamische Tabelle für Abmessungen, Länge, Stück und Volumen
//             pw.Table(
//               border: pw.TableBorder(
//                 horizontalInside: pw.BorderSide(width: 2),
//               ),
//               children: [
//                 pw.TableRow(
//                   children: [
//                     pw.Padding(
//                       padding: const pw.EdgeInsets.all(4),
//                       child: pw.RichText(
//                         text: pw.TextSpan(
//                           children: [
//                             pw.TextSpan(
//                               text: 'Maße ',
//                               style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold),
//                             ),
//                             pw.TextSpan(
//                               text: '[mm x mm]',
//                               style: pw.TextStyle(fontSize: 15),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                     pw.Padding(
//                       padding: const pw.EdgeInsets.all(4),
//                       child: pw.RichText(
//                         text: pw.TextSpan(
//                           children: [
//                             pw.TextSpan(
//                               text: 'Länge ',
//                               style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold),
//                             ),
//                             pw.TextSpan(
//                               text: '[m]',
//                               style: pw.TextStyle(fontSize: 15),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                     pw.Padding(
//                       padding: const pw.EdgeInsets.all(4),
//                       child: pw.Text(
//                         'Stück',
//                         style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold),
//                       ),
//                     ),
//                     pw.Padding(
//                       padding: const pw.EdgeInsets.all(4),
//                       child: pw.Text(
//                         'm³',
//                         style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold),
//                       ),
//                     ),
//                   ],
//                 ),
//                 for (var row in tableRows)
//                   pw.TableRow(
//                     children: [
//                       pw.Padding(
//                         padding: const pw.EdgeInsets.all(8),
//                         child: pw.Text(
//                           row['Abmessung'] ?? '',
//                           style: pw.TextStyle(fontSize: 25, fontWeight: pw.FontWeight.bold),
//                         ),
//                       ),
//                       pw.Padding(
//                         padding: const pw.EdgeInsets.all(8),
//                         child: pw.Text(
//                           row['Länge'] ?? '',
//                           style: pw.TextStyle(fontSize: 25, fontWeight: pw.FontWeight.bold),
//                         ),
//                       ),
//                       pw.Padding(
//                         padding: const pw.EdgeInsets.all(8),
//                         child: pw.Text(
//                           row['Stück'] ?? '',
//                           style: pw.TextStyle(fontSize: 25, fontWeight: pw.FontWeight.bold),
//                         ),
//                       ),
//                       pw.Padding(
//                         padding: const pw.EdgeInsets.all(8),
//                         child: pw.Text(
//                           _calculateVolume(row) ?? '0.0',
//                           style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
//                         ),
//                       ),
//                     ],
//                   ),
//               ],
//             ),
//             pw.SizedBox(height: 40),
//
//             // Volumenberechnung und Bemerkung
//             pw.Text('Gesamtvolumen: ${totalVolume.toStringAsFixed(2)} m³', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
//             pw.SizedBox(height: 10),
//             pw.Text('Bemerkung:', style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold)),
//             pw.Text(
//               selectedBemerkungPaketZettelHobeln.isNotEmpty ? selectedBemerkungPaketZettelHobeln : '-',
//               style: pw.TextStyle(fontSize: 25, fontWeight: pw.FontWeight.bold),
//             ),
//           ],
//         ),
//       ),
//     );
//
//     final output = await getTemporaryDirectory();
//     final file = File("${output.path}/example.pdf");
//     await file.writeAsBytes(await pdf.save());
//     return file;
//   }
//
//
//
//   Future<File> _generatePdf() async {
//     final pdf = pw.Document();
//
//     // Lade das Bild-Logo aus dem Ordner 'images'
//     final ByteData logoData = await rootBundle.load('images/logo_sw.jpg');
//     final Uint8List logoBytes = logoData.buffer.asUint8List();
//
//     final image = pw.MemoryImage(logoBytes);
//
//     // Funktion zum Erstellen von Tabelleneinträgen ohne vertikale Linien
//     pw.TableRow _buildRow(String value, String label) {
//       return pw.TableRow(
//         children: [
//           pw.Padding(
//             padding: const pw.EdgeInsets.all(12),
//             child: pw.Container(
//               width: 110, // Mindestbreite für das Label festlegen
//               child: pw.Text(
//                 label,
//                 style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold),
//               ),
//             ),
//           ),
//           pw.Padding(
//             padding: const pw.EdgeInsets.all(12),
//             child: pw.Container(
//               width: 150, // Mindestbreite für den Wert festlegen
//               child: pw.Text(
//                 value,
//                 style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold),
//               ),
//             ),
//           ),
//         ],
//       );
//     }
//
//     pdf.addPage(
//       pw.MultiPage(
//         pageFormat: PdfPageFormat.a4,
//         build: (pw.Context context) => [
//           // Logo und Barcode in einer Zeile
//           pw.Row(
//             mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//             children: [
//               pw.Image(image, width: 200, height: 100), // Verkleinertes Logo
//               pw.BarcodeWidget(
//                 data: barcodeData,
//                 barcode: pw.Barcode.code128(),
//                 width: 220, // Angepasste Breite des Barcodes
//                 height: 70, // Angepasste Höhe des Barcodes
//               ),
//             ],
//           ),
//           pw.SizedBox(height: 20),
//
//           // Tabelle für Kunde, Auftragsnr., Kommission mit dickeren Rändern und ohne vertikale Striche
//           pw.Table(
//             border: pw.TableBorder(
//               horizontalInside: pw.BorderSide(width: 2), // Nur horizontale Linien
//             ),
//             children: [
//               _buildRow(selectedFirmaPaketZettelHobeln.isNotEmpty ? selectedFirmaPaketZettelHobeln : '', 'Kunde'),
//               _buildRow(selectedAuftragsNrPaketZettelHobeln.isNotEmpty ? selectedAuftragsNrPaketZettelHobeln : '', 'Auftrag'),
//               _buildRow(selectedKommissionPaketZettelHobeln.isNotEmpty ? selectedKommissionPaketZettelHobeln : '', 'Kommission'),
//             ],
//           ),
//           pw.SizedBox(height: 20),
//
//           // Dynamische Tabelle für Abmessungen, Länge, Stück und Volumen mit dickeren horizontalen Strichen
//           pw.Table(
//             border: pw.TableBorder(
//               horizontalInside: pw.BorderSide(width: 2), // Nur horizontale Linien
//             ),
//             children: [
//               pw.TableRow(
//                 children: [
//                   pw.Padding(
//                     padding: const pw.EdgeInsets.all(4),
//                     child: pw.RichText(
//                       text: pw.TextSpan(
//                         children: [
//                           pw.TextSpan(
//                             text: 'Maße ',
//                             style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold),
//                           ),
//                           pw.TextSpan(
//                             text: '[mm x mm]',
//                             style: pw.TextStyle(fontSize: 15), // Schriftgröße 15 für Maßeinheit
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                   pw.Padding(
//                     padding: const pw.EdgeInsets.all(4),
//                     child: pw.RichText(
//                       text: pw.TextSpan(
//                         children: [
//                           pw.TextSpan(
//                             text: 'Länge ',
//                             style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold),
//                           ),
//                           pw.TextSpan(
//                             text: '[m]',
//                             style: pw.TextStyle(fontSize: 15), // Schriftgröße 15 für Maßeinheit
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                   pw.Padding(
//                     padding: const pw.EdgeInsets.all(4),
//                     child: pw.Text(
//                       'Stück',
//                       style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold),
//                     ),
//                   ),
//                   pw.Padding(
//                     padding: const pw.EdgeInsets.all(4),
//                     child: pw.Text(
//                       'm³',
//                       style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold),
//                     ),
//                   ),
//                 ],
//               ),
//               for (var row in tableRows)
//                 pw.TableRow(
//                   children: [
//                     pw.Padding(
//                       padding: const pw.EdgeInsets.all(8),
//                       child: pw.Text(
//                         row['Abmessung'] ?? '',
//                         style: pw.TextStyle(fontSize: 25, fontWeight: pw.FontWeight.bold),
//                       ),
//                     ),
//                     pw.Padding(
//                       padding: const pw.EdgeInsets.all(8),
//                       child: pw.Text(
//                         row['Länge'] ?? '',
//                         style: pw.TextStyle(fontSize: 25, fontWeight: pw.FontWeight.bold),
//                       ),
//                     ),
//                     pw.Padding(
//                       padding: const pw.EdgeInsets.all(8),
//                       child: pw.Text(
//                         row['Stück'] ?? '',
//                         style: pw.TextStyle(fontSize: 25, fontWeight: pw.FontWeight.bold),
//                       ),
//                     ),
//                     pw.Padding(
//                       padding: const pw.EdgeInsets.all(8),
//                       child: pw.Text(
//                         _calculateVolume(row) ?? '0.0', // Hier wird das Volumen berechnet
//                         style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
//                       ),
//                     ),
//                   ],
//                 ),
//             ],
//           ),
//           pw.SizedBox(height: 40),
//
//           // Volumenberechnung und Bemerkung
//           pw.Text('Gesamtvolumen: ${totalVolume.toStringAsFixed(2)} m³', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
//           pw.SizedBox(height: 10),
//           pw.Text('Bemerkung:', style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold)),
//           pw.Text(
//             selectedBemerkungPaketZettelHobeln.isNotEmpty ? selectedBemerkungPaketZettelHobeln : '-',
//             style: pw.TextStyle(fontSize: 25, fontWeight: pw.FontWeight.bold),
//           ),
//         ],
//       ),
//     );
//
//     final output = await getTemporaryDirectory();
//     final file = File("${output.path}/example.pdf");
//     await file.writeAsBytes(await pdf.save());
//     return file;
//   }
//
// // Funktion zur Volumenberechnung für jede Zeile
//   String? _calculateVolume(Map<String, String> row) {
//     double width = double.tryParse(row['Breite'] ?? '') ?? 0.0;
//     double height = double.tryParse(row['Höhe'] ?? '') ?? 0.0;
//     double length = double.tryParse(row['Länge'] ?? '') ?? 0.0;
//     int pieces = int.tryParse(row['Stück'] ?? '') ?? 0;
//
//     // Berechnung des Volumens in m³ (durch 1.000.000 teilen)
//     double volume = (width * height * length * pieces) / 1000000.0;
//
//    totalVolume += volume; // Zum Gesamtvolumen addieren
//
//     return volume.toStringAsFixed(2); // Volumen als String zurückgeben
//   }
//
//   // Funktion zum Überprüfen des Druckerstatus
//
// // Funktion zum Überprüfen des Druckerstatus
//   // Funktion zum Überprüfen des Druckerstatus
//   Future<void> _checkPrinterStatus() async {
//     try {
//       var printer = Printer();
//       var printInfo = PrinterInfo();
//       printInfo.printerModel = Model.QL_1110NWB;
//       printInfo.port = Port.NET;
//
//       // Setze die Druckerinfo, um den Status zu prüfen
//       await printer.setPrinterInfo(printInfo);
//
//       // Hole die Liste der verfügbaren Drucker im Netzwerk
//       List<NetPrinter> printers = await printer.getNetPrinters([Model.QL_1110NWB.getName()]);
//
//       if (mounted) {
//         setState(() {
//           _isPrinterOnline = printers.isNotEmpty;
//           _indicatorColor = _isPrinterOnline ? Colors.green : Colors.red; // Aktualisiert die Leuchte auf Grün oder Rot
//           _printerSearching = false; // Beendet die Suche
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _isPrinterOnline = false;
//           _indicatorColor = Colors.red; // Setzt die Leuchte auf Rot bei Fehlern
//           _printerSearching = false; // Beendet die Suche
//         });
//       }
//     }
//   }
//
//   // Funktion zum Anzeigen eines Toasts, wenn die Leuchte angeklickt wird
//   // Funktion zum Anzeigen eines Toasts, wenn die Leuchte angeklickt wird und Suche beginnt
//   void _showPrinterStatusToast() {
//     if (!_printerSearching) {
//       setState(() {
//         _indicatorColor = Colors.orange; // Setze die Leuchte auf Orange, wenn die Suche beginnt
//       });
//       Fluttertoast.showToast(
//         msg: "Drucker wird gesucht...",
//         toastLength: Toast.LENGTH_SHORT,
//         gravity: ToastGravity.BOTTOM,
//         backgroundColor: Colors.black,
//         textColor: Colors.white,
//       );
//
//       // Beginne die Druckersuche nach dem Klick
//       _checkPrinterStatus();
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Center(child: Text('Paketzettel - Hobeln',style:  smallHeadline4_0)),
//         actions: [
//
//           GestureDetector(
//             onTap: _showPrinterStatusToast,
//             child: Padding(
//     padding: const EdgeInsets.all(8.0),
//     child: Container(
//     width: 20,
//     height: 20,
//     decoration: BoxDecoration(
//     shape: BoxShape.circle,
//     color:_indicatorColor,
//     boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.6), spreadRadius: 2, blurRadius: 2, offset: Offset(0, 0), ),],
//     )))
//           ),
//           IconButton(
//             icon: const Icon(Icons.settings),
//
//             onPressed: () {
//               showPrinterScreenSettingsDialog(context);
//             },
//           ),
//         ],
//       ),
//       resizeToAvoidBottomInset: false,
//       body:  SingleChildScrollView(
//         child: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: <Widget>[
// SizedBox(height: 0.02*h,),
//               isLoading  // Überprüfe den Ladezustand
//                   ? CircularProgressIndicator()  // Zeige den CircularProgressIndicator, solange geladen wird
//                   :
//               BarcodeWidget(
//                 data: barcodeData,
//                 barcode: pw.Barcode.code128(),
//                 width: 200,
//                 height: 80,
//               ),
//
//
//               Padding(
//                 padding: const EdgeInsets.all(10.0),
//                 child: Table(
//                   border:TableBorder(
//                     horizontalInside: BorderSide(color: Colors.grey, width: 0.5), // Nur horizontale Linie zwischen den Zeilen
//                   ),
//                   columnWidths: const {
//                     0: FixedColumnWidth(150.0),
//                     1: FlexColumnWidth(),
//                   },
//                   children: [
//                     // Zeile für Paket-Nr. Intern
//
//                     TableRow(children: [
//                       Padding(
//                         padding: const EdgeInsets.all(8.0),
//                         child: Text('Kunde', style: headline20),
//                       ),
//                       Padding(
//                         padding: const EdgeInsets.all(8.0),
//                         child: GestureDetector(
//                           onTap: ()
//                           {
//                             showSingleInputDialog(context,false,1,"","Firma ",  selectedFirmaPaketZettelHobeln,  onSave: (value) {
//                               setState(() {
//                                 selectedFirmaPaketZettelHobeln = value; // Speichert die Auftragsnummer
//                               });});
//                           //   showInputDialog(
//                           //
//                           //   context,
//                           //
//                           //   'Firma auswählen',
//                           //   1,
//                           //   true,
//                           //   selectedFirmaPaketZettelHobeln,
//                           //   onSave: (value) {
//                           //     setState(() {
//                           //       selectedFirmaPaketZettelHobeln = value; // Speichert den ausgewählten Kunden
//                           //     });
//                           //   },
//                           // );
//   },
//                           child:
//                           selectedFirmaPaketZettelHobeln.isNotEmpty?
//                           Text(
//                             selectedFirmaPaketZettelHobeln.isNotEmpty ? selectedFirmaPaketZettelHobeln : 'Ausfüllen',
//                             style:  headline20.copyWith(
//                               color:  goldenColour,
//                             )
//                           ):Icon(Icons.edit,color: goldenColour,),
//                         ),
//                       ),
//                     ]),
//                     TableRow(children: [
//                       Padding(
//                         padding: const EdgeInsets.all(8.0),
//                         child: Text('Auftragsnr.', style: headline20),
//                       ),
//                       Padding(
//                         padding: const EdgeInsets.all(8.0),
//                         child: GestureDetector(
//                           onTap: () {
//                             showSingleInputDialog(context,true,1,"","Auftragsnummer eingeben",  selectedAuftragsNrPaketZettelHobeln,  onSave: (value) {
//                                     setState(() {
//                                       selectedAuftragsNrPaketZettelHobeln = value; // Speichert die Auftragsnummer
//                                     });});
//                           //     showInputDialog(
//                           //
//                           //   context,
//                           //   'Auftragsnummer eingeben',
//                           //   1,
//                           //   false,
//                           //   _auftragNr,
//                           //   onSave: (value) {
//                           //     setState(() {
//                           //       _auftragNr = value; // Speichert die Auftragsnummer
//                           //     });
//                           //   },
//                           // );
//                               },
//
//                           child:  selectedAuftragsNrPaketZettelHobeln.isNotEmpty ?Text(
//                             selectedAuftragsNrPaketZettelHobeln.isNotEmpty ? selectedAuftragsNrPaketZettelHobeln : 'Ausfüllen',
//                             style:  headline20.copyWith(
//                               color:  goldenColour,
//                             ),
//                           )
//                               :Icon(Icons.edit,color: goldenColour,),
//                         ),
//                       ),
//                     ]),
//                     TableRow(children: [
//                       Padding(
//                         padding: const EdgeInsets.all(8.0),
//                         child: Text('Kommission', style: headline20),
//                       ),
//                       Padding(
//                         padding: const EdgeInsets.all(8.0),
//                         child: GestureDetector(
//                           onTap: () {
//                             showSingleInputDialog(context,false,1,"",'Kommission eingeben',selectedKommissionPaketZettelHobeln,  onSave: (value) {
//                               setState(() {
//                                 selectedKommissionPaketZettelHobeln = value;
//                               });});
//                           //  showInputDialog(
//                           //   context,
//                           //   'Kommission eingeben',
//                           //   1,
//                           //   false,
//                           //   _kommission,
//                           //   onSave: (value) {
//                           //     setState(() {
//                           //       _kommission = value; // Speichert die Kommission
//                           //     });
//                           //   },
//                           // );
//                            },
//                           child:  selectedKommissionPaketZettelHobeln.isNotEmpty ? Text(
//                             selectedKommissionPaketZettelHobeln.isNotEmpty ?selectedKommissionPaketZettelHobeln : 'Ausfüllen',
//                             style:  headline20.copyWith(
//                               color:  goldenColour,
//                             ),
//                           ) :Icon(Icons.edit,color: goldenColour,),
//                         ),
//                       ),
//                     ]),
//
//                   ],
//                 ),
//
//               ),
//               Padding(
//                 padding: const EdgeInsets.all(20.0),
//                 child: _buildTable(),
//               ),
// //               Padding(
// //                 padding: const EdgeInsets.all(20.0),
// //                 child: Container(
// //                 // decoration:  BoxDecoration(
// //                     //  border: Border.all(color: Colors.grey),),
// //                   child: Column(
// //                     children: [
// //                       Row(
// //                         mainAxisAlignment: MainAxisAlignment.start,
// //                         children: [
// //                           Text(
// //
// //                            'Bemerkung',
// //                             style:  headline20.copyWith(
// // color: goldenColour
// //                             ),
// //                           ),
// //                         ],
// //                       ),
// //
// //                       TextField(
// //                         decoration: InputDecoration(labelText: ' '),
// //                         maxLines: 3, // Oder mehr, je nach gewünschter Größe des Feldes
// //                         onChanged: (value) {
// //                           setState(() {
// //                             _bemerkung = value; // Speichere den Bemerkungstext
// //                           });
// //                         },
// //                       ),
// //                     ],
// //                   ),
// //                 ),
// //               ),
//               Padding(
//                 padding: const EdgeInsets.all(20.0),
//                 child: Container(
//                   child: Column(
//                     children: [
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.start,
//                         children: [
//                           Text(
//                             'Bemerkung',
//                             style: headline20.copyWith(color: goldenColour),
//                           ),
//                         ],
//                       ),
//                     SizedBox(height: h*0.01,child: Divider(color: Colors.grey,),),
//                       Container(
//                         height: h*0.1,
//                         child: Padding(
//                           padding: const EdgeInsets.all(8.0),
//                           child: GestureDetector(
//                             onTap: ()
//
//                                {
//
//                                  showSingleInputDialog(context,false,6,"","Bemerkung eingeben", selectedBemerkungPaketZettelHobeln,  onSave: (value) {
//                                    setState(() {
//                                      selectedBemerkungPaketZettelHobeln= value; // Speichert die Auftragsnummer
//                                    });});
//                             //     showInputDialog(context, 'Bemerkung eingeben', 4, false, _bemerkung,
//                             //   onSave: (value) {
//                             //     setState(() {
//                             //       _bemerkung = value; // Speichert die Bemerkung
//                             //     });
//                             //   },
//                             // );
//   },
//                             child:  selectedBemerkungPaketZettelHobeln.isNotEmpty
//                                 ? Text(
//                               selectedBemerkungPaketZettelHobeln,
//                               style: headline20.copyWith(
//                                 color: Colors.black87,
//                               ),
//                             )
//                                 : Icon(Icons.edit, color: goldenColour,size: 50,),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//
//             ],
//           ),
//         ),
//       ),
//
//       floatingActionButton: Column(
//         mainAxisAlignment: MainAxisAlignment.end,
//         children: [
//
//               // FloatingActionButton(
//               //   backgroundColor: goldenColour,
//               //   heroTag: 'pdf_download',
//               //   onPressed: _downloadPdf,
//               //   tooltip: 'Download PDF',
//               //   child: Icon(Icons.picture_as_pdf),
//               // ),
//               // SizedBox(height: 16), // Abstand zwischen den Buttons
//               // Button zum Drucken
//               FloatingActionButton(
//                 backgroundColor: goldenColour,
//                 heroTag: 'print',
//                 onPressed: () async {
//                   totalVolume=0;
//
//                   if (_isPrinterOnline == false) {
//                     // Zeige einen Ja/Nein-Dialog, wenn der Drucker offline ist
//                     await showDialog(
//                     context: context,
//                     builder: (BuildContext context) {
//                       return AlertDialog(
//                         title: Text("Drucker offline", style: smallHeadline4_0),
//                         content: Text("Der Drucker ist offline. Paketzettel trotzdem erstellen und PDF anlegen?"),
//                         actions: [
//                           TextButton(
//                             child: Text("Nein"),
//                             onPressed: () {
//                               Navigator.of(context).pop(); // Schließt den Dialog
//                             },
//                           ),
//                           TextButton(
//                             child: Text("Ja"),
//                             onPressed: () async {
//                               Navigator.of(context).pop(); // Schließt den Dialog
//
//                               final pdfFile = await _generatePdf();
//                               Uint8List pdfBytes = await pdfFile.readAsBytes();
//                               await uploadPlanerPackagePDFFileToGoogleDrive(barcodeData, pdfBytes);
//
//                               await _exportToDatabase(); // Export der Daten wird trotzdem durchgeführt
//                               _checkToClearValues(clearPrinterValuesAfterInput);
//
//
//                               AppToast.show(message: "Paketzettel $barcodeData erfolgreich erstellt",height: h);
//                               await FirebaseFirestore.instance.collection('companies').doc('100').set({'letztesHobelPaket':FieldValue.increment(1),}, SetOptions(merge: true));
//                               _loadBarcodeFromFirestore();
//                             },
//                           ),
//                         ],
//                       );
//                     },
//                     );
//                   }else{
//                     await printLabel(context);
//                     _exportToDatabase();
//                     _checkToClearValues(clearPrinterValuesAfterInput);
//
//
//                     AppToast.show(message: "Paketzettel $barcodeData erfolgreich erstellt",height: h);
//                     await FirebaseFirestore.instance.collection('companies').doc('100').set({'letztesHobelPaket':FieldValue.increment(1),}, SetOptions(merge: true));
//                     _loadBarcodeFromFirestore();
//
//                   }
//
//
//                 },
//                 tooltip: 'Print',
//                 child: Icon(Icons.print),
//               ),
//
//
//
//         ],
//       ),
//     );
//   }
//
//   void _checkToClearValues(bool clearPrinterValuesAfterInput) {
//     if(clearPrinterValuesAfterInput==true){
//
//        selectedAuftragsNrPaketZettelHobeln = '';
//        selectedKommissionPaketZettelHobeln = '';
//        selectedBemerkungPaketZettelHobeln = '';
//
//       selectedFirmaPaketZettelHobeln = '';
//      tableRows = [
//         {'Abmessung': '', 'Länge': '', 'Stück': ''},
//       ];
//        lengthControllers.insert(0, TextEditingController());
//        pieceControllers.insert(0, TextEditingController());
//     }
//
//   }
// }
//
