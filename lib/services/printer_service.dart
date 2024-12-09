import 'dart:io';
import 'package:another_brother/label_info.dart';
import 'package:another_brother/printer_info.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';


class PrinterService {
  static NetPrinter? _selectedPrinter;
  static BluetoothPrinter? _selectedBluetoothPrinter;
  static bool _isPrinterOnline = false;
  static Map<String, String> printerNicknames = {};
  static String? defaultPrinterMAC;
  static bool _printerSearching = false;
  static void Function(String)? onStatusUpdate;

  // Getter Methoden
  static bool isPrinterOnline() => _isPrinterOnline;
  static bool isPrinterSearching() => _printerSearching;
  static NetPrinter? getSelectedPrinter() => _selectedPrinter;
  static String? getPrinterNickname(String macAddress) => printerNicknames[macAddress];
  static String? getDefaultPrinterMAC() => defaultPrinterMAC;


  static void updateStatus(String status) {
    _updateStatus(status);
  }

  static Future<void> loadPrinterSettings() async {
    try {
      QuerySnapshot printersSnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc('100')
          .collection('printers')
          .get();

      DocumentSnapshot settingsDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc('100')
          .get();

      printerNicknames = Map.fromEntries(
        printersSnapshot.docs.map((doc) => MapEntry(
          doc['macAddress'] as String,
          doc['nickname'] as String,
        )),
      );
      defaultPrinterMAC = settingsDoc.get('defaultPrinter') as String?;
    } catch (e) {
      print("Fehler beim Laden der Drucker-Einstellungen: $e");
    }
  }

  static Future<bool> initializePrinter() async {
    try {
      _updateStatus("Lade Drucker-Einstellungen...");
      await loadPrinterSettings();

      DocumentSnapshot settingsDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc('100')
          .get();
      bool useBluetoothFirst = settingsDoc.get('bluetoothFirst') ?? true;

      if (useBluetoothFirst) {
        bool bluetoothSuccess = await _initializeBluetoothPrinter();
        if (bluetoothSuccess) return true;

        return await _initializeNetworkPrinter();
      } else {
        bool networkSuccess = await _initializeNetworkPrinter();
        if (networkSuccess) return true;

        return await _initializeBluetoothPrinter();
      }
    } catch (e) {
      _updateStatus("Fehler bei der Drucker-Initialisierung: $e");
      _isPrinterOnline = false;
      return false;
    }
  }
  static Future<bool> _initializeBluetoothPrinter() async {
    try {
      _updateStatus("Prüfe Bluetooth-Berechtigungen...");
      bool hasPermissions = await _checkBluetoothPermissions();
      if (!hasPermissions) {
        _updateStatus("Bluetooth-Berechtigungen nicht erteilt");
        return false;
      }

      var printer = Printer();
      var printInfo = PrinterInfo();
      await printer.setPrinterInfo(printInfo);

      List<BluetoothPrinter> foundPrinters = [];

      for (int i = 0; i < 3; i++) {
        try {
          _updateStatus("Bluetooth-Suchversuch ${i + 1} von 3...");

          foundPrinters.addAll(await printer.getBluetoothPrinters([Model.QL_820NWB.getName()]));
          foundPrinters.addAll(await printer.getBluetoothPrinters([Model.QL_1110NWB.getName()]));

          if (foundPrinters.isNotEmpty) {
            foundPrinters.forEach((printer) {
              _updateStatus("Gefunden: ${printer.modelName} (${printer.macAddress})");
            });
            break;
          }

          _updateStatus("Keine Drucker in Versuch ${i + 1} gefunden, versuche erneut...");
          await Future.delayed(const Duration(seconds: 2));
        } catch (e) {
          _updateStatus("Fehler in Suchversuch ${i + 1}: $e");
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      if (foundPrinters.isEmpty) {
        _updateStatus("Keine Bluetooth-Drucker gefunden");
        return false;
      }

      _selectedBluetoothPrinter = foundPrinters.first;
      _updateStatus("Bluetooth-Drucker ausgewählt: ${_selectedBluetoothPrinter?.modelName}");
      return true;
    } catch (e) {
      _updateStatus("Bluetooth-Initialisierungsfehler: $e");
      return false;
    }
  }

  static Future<bool> _initializeNetworkPrinter() async {
    _updateStatus("Suche WLAN-Drucker...");
    var printer = Printer();
    var printInfo = PrinterInfo();
    await printer.setPrinterInfo(printInfo);

    List<NetPrinter> foundPrinters = [];
    foundPrinters.addAll(await printer.getNetPrinters([Model.QL_820NWB.getName()]));
    foundPrinters.addAll(await printer.getNetPrinters([Model.QL_1110NWB.getName()]));

    if (foundPrinters.isEmpty) {
      _updateStatus("Keine WLAN-Drucker gefunden");
      _isPrinterOnline = false;
      return false;
    }

    _selectedPrinter = defaultPrinterMAC != null
        ? foundPrinters.firstWhere(
            (printer) => printer.macAddress == defaultPrinterMAC,
        orElse: () => foundPrinters.first)
        : foundPrinters.first;

    _updateStatus("WLAN-Drucker gefunden: ${_selectedPrinter?.modelName}");
    _isPrinterOnline = true;
    return true;
  }
  static Future<bool> _checkBluetoothPermissions() async {
    if (Platform.isAndroid) {
      final permissions = <Permission>[
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.location,
      ];

      Map<Permission, PermissionStatus> statuses = await permissions.request();
      return statuses.values.every((status) => status.isGranted);
    }
    return true;
  }

  static Future<void> printBarcodeLabel({
    required String barcodeData,
    required double labelWidth,
    required int quantity,
    required BuildContext context,
  }) async {
    try {
      if (!await initializePrinter()) {
        throw Exception("Kein Drucker verfügbar");
      }

      var printer = Printer();
      var printInfo = PrinterInfo();

      // Konfiguriere Drucker basierend auf Verbindungstyp
      if (_selectedBluetoothPrinter != null) {
        _configureBluetooth(printInfo);
      } else if (_selectedPrinter != null) {
        _configureNetwork(printInfo);
      } else {
        throw Exception("Kein Drucker ausgewählt");
      }

      // Setze Label-Größe
      _configureLabelSize(printInfo, labelWidth);

      // Allgemeine Einstellungen
      printInfo.printMode = PrintMode.FIT_TO_PAGE;
      printInfo.isAutoCut = true;
      printInfo.printQuality = PrintQuality.HIGH_RESOLUTION;
      printInfo.numberOfCopies = quantity;

      await printer.setPrinterInfo(printInfo);

      // Generiere und drucke das Label
      final pdfFile = await _generateBarcodePdf(barcodeData, labelWidth);
      final result = await printer.printPdfFile(pdfFile.path, 1);

      if (result.errorCode != ErrorCode.ERROR_NONE) {
        throw Exception("Druckfehler: ${result.errorCode}");
      }

      // Logging des Druckvorgangs
      await _logPrintJob(barcodeData, quantity, labelWidth);

    } catch (e) {
      print("Druckfehler: $e");
      throw e;
    }
  }

  static void _configureBluetooth(PrinterInfo printInfo) {
    printInfo.printerModel = _selectedBluetoothPrinter!.modelName.contains("1110")
        ? Model.QL_1110NWB
        : Model.QL_820NWB;
    printInfo.port = Port.BLUETOOTH;
    printInfo.macAddress = _selectedBluetoothPrinter!.macAddress;
  }

  static void _configureNetwork(PrinterInfo printInfo) {
    printInfo.printerModel = _selectedPrinter!.modelName.contains("1110")
        ? Model.QL_1110NWB
        : Model.QL_820NWB;
    printInfo.port = Port.NET;
    printInfo.ipAddress = _selectedPrinter!.ipAddress;
  }

  static void _configureLabelSize(PrinterInfo printInfo, double width) {
    final labelMap = {
      103.0: QL1100.W103,
      62.0: QL1100.W62,
      54.0: QL1100.W54,
      50.0: QL1100.W50,
      38.0: QL1100.W38,
      29.0: QL1100.W29,
    };

    var labelType = labelMap[width];
    if (labelType != null) {
      printInfo.labelNameIndex = QL1100.ordinalFromID(labelType.getId());
    }
  }

  static Future<File> _generateBarcodePdf(String barcodeData, double pageWidth) async {
    final pdf = pw.Document();
    double pageHeight = 21.0; // Feste Höhe für Endlos-Etiketten

    // Berechne optimale Barcode-Größe
    double barcodeWidth = pageWidth * 0.9;
    double barcodeHeight = pageHeight * 0.5;
    double fontSize = pageWidth * 0.05;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          pageWidth,
          pageHeight,
          marginAll: 0,
        ),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.BarcodeWidget(
                  data: barcodeData,
                  barcode: pw.Barcode.code128(),
                  width: barcodeWidth,
                  height: barcodeHeight,
                  drawText: false,
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  barcodeData,
                  style: pw.TextStyle(
                    fontSize: fontSize,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/barcode_label.pdf");
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<void> _logPrintJob(String barcode, int quantity, double labelWidth) async {
    await FirebaseFirestore.instance.collection('print_logs').add({
      'timestamp': FieldValue.serverTimestamp(),
      'barcode': barcode,
      'quantity': quantity,
      'labelWidth': labelWidth,
      'printerType': _selectedBluetoothPrinter != null ? 'bluetooth' : 'network',
      'printerModel': _selectedBluetoothPrinter?.modelName ?? _selectedPrinter?.modelName,
    });

    await FirebaseFirestore.instance
        .collection('general_data')
        .doc('printer')
        .set({
      'totalLabelsPrinted': FieldValue.increment(quantity),
      'lastPrintTimestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static void _updateStatus(String status) {
    print(status);
    onStatusUpdate?.call(status);
  }
}