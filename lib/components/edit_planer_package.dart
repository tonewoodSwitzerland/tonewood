import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';

import 'package:flutter/services.dart';

import 'dart:async';

import 'package:pdf/widgets.dart' as pw;


class EditPlanerPackageDialog extends StatefulWidget {
  final Map<String, dynamic> planerPackageData;

  EditPlanerPackageDialog({required this.planerPackageData});

  @override
  _EditPlanerPackageDialogState createState() => _EditPlanerPackageDialogState();
}

class _EditPlanerPackageDialogState extends State<EditPlanerPackageDialog> {
  // Controller für die Eingabefelder
  late TextEditingController auftragsnrController;
  late TextEditingController kundeController;
  late TextEditingController kommissionController;
  late TextEditingController bemerkungController;
  List<Map<String, dynamic>> positions = [];
  String barcodeData = '';
double totalVolume=0.0;
  @override
  void initState() {
    super.initState();
    auftragsnrController = TextEditingController(text: widget.planerPackageData['Auftragsnr'] ?? '');
    kundeController = TextEditingController(text: widget.planerPackageData['Kunde'] ?? '');
    kommissionController = TextEditingController(text: widget.planerPackageData['Kommission'] ?? '');
    bemerkungController = TextEditingController(text: widget.planerPackageData['Bemerkung'] ?? '');
    barcodeData = widget.planerPackageData['Barcode'] ?? '';
    print(widget.planerPackageData['positions']);
    positions = List<Map<String, dynamic>>.from(widget.planerPackageData['positions']);
    totalVolume = _calculateTotalVolume(); // Berechne das Gesamtvolumen direkt beim Initialisieren

  }

  // Funktion zur Berechnung des Volumens für jede Position
  String _calculateVolume(Map<String, dynamic> position) {
    double width = double.tryParse(position['B']?.toString() ?? '') ?? 0.0;
    double height = double.tryParse(position['H']?.toString() ?? '') ?? 0.0;
    double length = double.tryParse(position['L']?.toString() ?? '') ?? 0.0;
    int pieces = int.tryParse(position['Stk']?.toString() ?? '') ?? 0;

    double volume = (width * height * length * pieces) / 1000000.0; // Volumen in m³
    return volume.toStringAsFixed(2);
  }

  // Berechne das Gesamtvolumen für alle Positionen
  double _calculateTotalVolume() {
    double total = 0.0;
    for (var position in positions) {
      double width = double.tryParse(position['B']?.toString() ?? '') ?? 0.0;
      double height = double.tryParse(position['H']?.toString() ?? '') ?? 0.0;
      double length = double.tryParse(position['L']?.toString() ?? '') ?? 0.0;
      int pieces = int.tryParse(position['Stk']?.toString() ?? '') ?? 0;
      double volume = (width * height * length * pieces) / 1000000.0;
      total += volume;
    }
    return total;
  }


  Future<void> saveChanges() async {
    try {
      // Aktualisiere die Daten im Firestore
      DocumentReference packageDocRef = FirebaseFirestore.instance.collection('products').doc(barcodeData);
      await packageDocRef.update({
        'Auftragsnr': auftragsnrController.text,
        'Kunde': kundeController.text,
        'Kommission': kommissionController.text,
        'Bemerkung': bemerkungController.text,
      });

     // Navigator.of(context).pop();
    } catch (e) {
      print("Fehler beim Speichern: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding:  EdgeInsets.all(16.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      elevation: 5,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(0.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barcode-Anzeige
              BarcodeWidget(
                data: barcodeData,
                barcode: pw.Barcode.code128(),
                width: 200,
                height: 80,
              ),
              const SizedBox(height: 20),

              // Eingabefelder für Kunde, Auftragsnummer, Kommission
              Table(
                border: TableBorder(
                  horizontalInside: BorderSide(color: Colors.grey, width: 0.5), // Nur horizontale Linie zwischen den Zeilen
                ),
                columnWidths: const {
                  0: FixedColumnWidth(150.0),
                  1: FlexColumnWidth(),
                },
                children: [
                  _buildTableRow('Kunde', kundeController),
                  _buildTableRow('Auftragsnr.', auftragsnrController),
                  _buildTableRow('Kommission', kommissionController),
                ],
              ),
              const SizedBox(height: 20),

              _buildPositionsTable(),

              const SizedBox(height: 20),
              // Gesamtvolumen anzeigen
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Gesamtvolumen: ${totalVolume.toStringAsFixed(2)} m³',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryAppColor),
                  ),
                ],
              ),



              const SizedBox(height: 20),
              // Bemerkung
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bemerkung',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryAppColor),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    enabled: false,
                    controller: bemerkungController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Bemerkung eingeben',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Buttons zum Speichern oder Abbrechen
              // Row(
              //   mainAxisAlignment: MainAxisAlignment.center,
              //   children: [
              //     // TextButton(
              //     //   onPressed: () {
              //     //  //   Navigator.of(context).pop();
              //     //   },
              //     //   child: const Text('Abbrechen', style: TextStyle(fontSize: 16)),
              //     // ),
              //     ElevatedButton(
              //       onPressed: saveChanges,
              //       child: const Text('Speichern', style: TextStyle(fontSize: 16)),
              //       style: ElevatedButton.styleFrom(
              //
              //       ),
              //     ),
              //   ],
              // ),
            ],
          ),
        ),
      ),
    );
  }
  // Tabelle für die Positionsdaten
  Widget _buildPositionsTable() {
    return Table(
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey, width: 0.5),
      ),
      columnWidths: const {
        0: FlexColumnWidth(6),
        1:  FlexColumnWidth(4),
        2:  FlexColumnWidth(3),
        3: FlexColumnWidth(2),
      },
      children: [
        TableRow(
          children: [
            _buildTableHeader('Maße [mm x mm]'),
            _buildTableHeader('Länge [m]'),
            _buildTableHeader('Stk'),
            _buildTableHeader('m³'),
          ],
        ),
        for (var position in positions)
          TableRow(
            children: [
              _buildTableCell('${position['B'] ?? ''} x ${position['H'] ?? ''}'),
              _buildTableCell('${position['L'] ?? ''}'),
              _buildTableCell('${position['Stk'] ?? ''}'),
              _buildTableCell(_calculateVolume(position)), // Volumen berechnen und anzeigen

            ],
          ),
      ],
    );
  }

  // Hilfsfunktionen für die Tabellenzellen
  Widget _buildTableHeader(String label) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        label,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTableCell(String value) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        value,
        style: TextStyle(fontSize: 16),
      ),
    );
  }
  TableRow _buildTableRow(String label, TextEditingController controller) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            label,
            style:smallHeadline4_0,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () {
              // showSingleInputDialog(context, false, 1, label, label, controller.text, onSave: (value) {
              //   setState(() {
              //     controller.text = value;
              //   });
              // });
            },
            child: Text(
              controller.text.isNotEmpty ? controller.text : 'Ausfüllen',
              style: smallHeadline4_0,

            ),
          ),
        ),
      ],
    );
  }

  Future<void> showSingleInputDialog(BuildContext context, bool onlyNumbers, int maxLines, String hintText, String headline, String initialNr, {Function(String nr)? onSave}) async {
    TextEditingController nrController = TextEditingController(text: initialNr);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(headline, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          content: TextField(
            maxLines: maxLines,
            controller: nrController,
            keyboardType: onlyNumbers ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(hintText: hintText),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () {
                if (onSave != null) {
                  onSave(nrController.text);
                }
                Navigator.of(context).pop();
              },
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );
  }
}
