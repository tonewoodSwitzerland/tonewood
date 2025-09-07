// customer_label_print_screen.dart

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart' hide Orientation;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:another_brother/printer_info.dart';
import 'package:another_brother/label_info.dart';

import '../services/customer.dart';
import '../services/icon_helper.dart';
import '../services/print_status.dart';
import '../services/printer_service.dart';
import '../constants.dart';
import 'customer_filter_service.dart';

class CustomerLabelPrintScreen extends StatefulWidget {
  const CustomerLabelPrintScreen({Key? key}) : super(key: key);

  @override
  State<CustomerLabelPrintScreen> createState() => _CustomerLabelPrintScreenState();
}

class _CustomerLabelPrintScreenState extends State<CustomerLabelPrintScreen> {
  // Label-Dimensionen (Endlosetiketten)
  List<LabelType> labelTypes = [];
  LabelType? selectedLabel;

  // Kunden und Vorschau
  List<Customer> selectedCustomers = [];
  int currentPreviewIndex = 0;

  // Drucker Status
  bool _isPrinterOnline = false;
  bool _printerSearching = false;
  String? _printerDetails;
  String _activeConnectionType = 'none';

  // Filter
  Map<String, dynamic> _activeFilters = CustomerFilterService.createEmptyFilter();

  @override
  void initState() {
    super.initState();
    _initializeLabelTypes();
    _loadLabelSettings();
    _checkPrinterStatus();
    _loadCustomersWithFilters();
  }

  void _initializeLabelTypes() {
    // Die 5 Endlosetiketten aus deiner Vorlage
    labelTypes = [
      LabelType(
        id: 'DK-22205',
        name: 'Endlospapier - DK-22205 - 62mm',
        description: '62mm x 30.48m',
        width: 62,
        height: 30480,
        possible_size: 'medium',
      ),
      LabelType(
        id: 'DK-N55224',
        name: 'Endlospapier - DK-N55224 - 54mm',
        description: '54mm x 30.48m',
        width: 54,
        height: 30480,
        possible_size: 'medium',
      ),
      LabelType(
        id: 'DK-22223',
        name: 'Endlospapier - DK-22223 - 50mm',
        description: '50mm x 30.48m',
        width: 50,
        height: 30480,
        possible_size: 'medium',
      ),
      LabelType(
        id: 'DK-22225',
        name: 'Endlospapier - DK-22225 - 38mm',
        description: '38mm x 30.48m',
        width: 38,
        height: 30480,
        possible_size: 'small',
      ),
      LabelType(
        id: 'DK-22210',
        name: 'Endlospapier - DK-22210 - 29mm',
        description: '29mm x 30.48m',
        width: 29,
        height: 30480,
        possible_size: 'small',
      ),
    ];
  }

  double _mmToPixels(double mm) {
    // Standard DPI für mobile Geräte (kann je nach Gerät variieren)
    // Die meisten Smartphones haben etwa 160-320 DPI
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

    // Umrechnung: 1 inch = 25.4mm
    // Flutter logical pixels = physical pixels / devicePixelRatio
    // Für genauere Ergebnisse könnte man die tatsächliche DPI des Geräts ermitteln
    const double baseDotsPerMm = 160 / 25.4; // ~6.3 dots per mm bei 160 DPI

    return mm * baseDotsPerMm;
  }


  Future<void> _loadLabelSettings() async {
    try {
      final officeDoc = await FirebaseFirestore.instance
          .collection('general_data')
          .doc('office')
          .get();

      if (officeDoc.exists && officeDoc.data()?['defaultAddressLabelWidth'] != null) {
        double labelWidth = officeDoc.data()!['defaultAddressLabelWidth'].toDouble();
        setState(() {
          selectedLabel = labelTypes.firstWhere(
                (label) => label.width == labelWidth,
            orElse: () => labelTypes[1], // 54mm als Standard
          );
        });
      } else {
        setState(() {
          selectedLabel = labelTypes[1]; // 54mm als Standard
        });
      }
    } catch (e) {
      print('Fehler beim Laden der Label-Einstellungen: $e');
      setState(() {
        selectedLabel = labelTypes[1]; // 54mm als Standard
      });
    }
  }

  Future<void> _loadCustomersWithFilters() async {
    try {
      // Lade gespeicherte Filter
      final savedFilters = await CustomerFilterService.loadSavedFilters().first;
      setState(() {
        _activeFilters = savedFilters;
      });

      // Lade alle Kunden
      final allCustomersSnapshot = await FirebaseFirestore.instance
          .collection('customers')
          .get();

      final allCustomers = allCustomersSnapshot.docs
          .map((doc) => {
        ...doc.data() as Map<String, dynamic>,
        'id': doc.id,
      })
          .toList();

      // Wende Filter an
      final filteredCustomers = await CustomerFilterService.applyClientSideFilters(
        allCustomers,
        _activeFilters,
      );

      // Konvertiere zu Customer-Objekten
      final customerObjects = filteredCustomers
          .map((data) => Customer.fromMap(data, data['id']))

          .toList();

      setState(() {
        selectedCustomers = customerObjects;
      });
    } catch (e) {
      print('Fehler beim Laden der Kunden: $e');
    }
  }

  Future<void> _checkPrinterStatus() async {
    if (!mounted) return;

    setState(() {
      _printerSearching = true;
    });

    try {
      bool useBluetoothFirst = await FirebaseFirestore.instance
          .collection('general_data')
          .doc('office')
          .get()
          .then((doc) => doc.get('bluetoothFirst') ?? true);

      var printer = Printer();
      var printInfo = PrinterInfo();
      printInfo.printerModel = Model.QL_820NWB;

      // Erste Verbindungsmethode versuchen
      bool connected = await _tryConnection(
          printer,
          printInfo,
          useBluetoothFirst ? Port.BLUETOOTH : Port.NET
      );

      // Wenn erste Methode fehlschlägt, zweite versuchen
      if (!connected) {
        connected = await _tryConnection(
            printer,
            printInfo,
            useBluetoothFirst ? Port.NET : Port.BLUETOOTH
        );
      }

      if (!mounted) return;

      setState(() {
        _printerSearching = false;
        if (!connected) {
          _isPrinterOnline = false;
          _printerDetails = null;
          _activeConnectionType = 'none';
        }
      });

    } catch (e) {
      print('Fehler bei Druckersuche: $e');
      if (!mounted) return;
      setState(() {
        _isPrinterOnline = false;
        _printerDetails = null;
        _activeConnectionType = 'none';
        _printerSearching = false;
      });
    }
  }

  Future<bool> _tryConnection(Printer printer, PrinterInfo printInfo, Port port) async {
    if (!mounted) return false;

    try {
      printInfo.port = port;
      await printer.setPrinterInfo(printInfo);

      if (port == Port.BLUETOOTH) {
        List<BluetoothPrinter> printers =
        await printer.getBluetoothPrinters([printInfo.printerModel.getName()]);

        if (printers.isNotEmpty && mounted) {
          setState(() {
            _isPrinterOnline = true;
            _activeConnectionType = 'bluetooth';
            _printerDetails = '${printers.first.modelName}';
          });
          return true;
        }
      } else {
        List<NetPrinter> printers =
        await printer.getNetPrinters([printInfo.printerModel.getName()]);

        if (printers.isNotEmpty && mounted) {
          setState(() {
            _isPrinterOnline = true;
            _activeConnectionType = 'wifi';
            _printerDetails = '${printers.first.modelName}';
          });
          return true;
        }
      }

      return false;
    } catch (e) {
      print('Verbindungsfehler für ${port.toString()}: $e');
      return false;
    }
  }

  double _calculateFontSize() {
    if (selectedLabel == null) return 10;

    // Schriftgröße in mm, dann in Pixel umrechnen
    return _mmToPixels(selectedLabel!.width * 0.12);
  }

  List<String> _formatAddressLines(Customer customer) {
    List<String> lines = [];

    // Zeile 1: Firma (falls vorhanden)
    if (customer.company?.isNotEmpty == true) {
      lines.add(customer.company!);
    }

    // Zeile 2: Vor- und Nachname
    String name = '';
    if (customer.firstName?.isNotEmpty == true) {
      name += customer.firstName!;
    }
    if (customer.lastName?.isNotEmpty == true) {
      if (name.isNotEmpty) name += ' ';
      name += customer.lastName!;
    }
    if (name.isNotEmpty) {
      lines.add(name);
    }

    // Zeile 3: Straße
    if (customer.street?.isNotEmpty == true) {
      lines.add(customer.street!);
    }

    // Zeile 4: Länderkürzel (falls nicht CH), PLZ und Ort
    String lastLine = '';

    // Länderkürzel nur wenn nicht Schweiz
    if (customer.countryCode?.isNotEmpty == true && customer.countryCode != 'CH') {
      lastLine += customer.countryCode! + '-';
    }

    if (customer.zipCode?.isNotEmpty == true) {
      lastLine += customer.zipCode!;
    }

    if (customer.city?.isNotEmpty == true) {
      if (lastLine.isNotEmpty) lastLine += ' ';
      lastLine += customer.city!;
    }

    if (lastLine.isNotEmpty) {
      lines.add(lastLine);
    }

    return lines;
  }
  Future<void> _printLabels() async {
    if (!_isPrinterOnline || selectedCustomers.isEmpty || selectedLabel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Drucker nicht bereit oder keine Kunden ausgewählt'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await PrintStatus.show(context, () async {
      try {
        PrintStatus.updateStatus("Initialisiere Drucker...");

        var printer = Printer();
        var printInfo = PrinterInfo();
        printInfo.printerModel = Model.QL_820NWB;

        // Konfiguriere für Endlosetiketten
        printInfo.isAutoCut = true;
        printInfo.isCutAtEnd = false; // Schneide nach jedem Label
        printInfo.numberOfCopies = 1;
        printInfo.printMode = PrintMode.FIT_TO_PAGE;
        printInfo.orientation = Orientation.LANDSCAPE;

        // Setze das richtige Label basierend auf der Breite
        switch(selectedLabel!.width.toInt()) {
          case 62:
            printInfo.labelNameIndex = QL700.ordinalFromID(QL700.W62.getId());
            break;
          case 54:
            printInfo.labelNameIndex = QL700.ordinalFromID(QL700.W54.getId());
            break;
          case 50:
            printInfo.labelNameIndex = QL700.ordinalFromID(QL700.W50.getId());
            break;
          case 38:
            printInfo.labelNameIndex = QL700.ordinalFromID(QL700.W38.getId());
            break;
          case 29:
            printInfo.labelNameIndex = QL700.ordinalFromID(QL700.W29.getId());
            break;
          default:
            throw Exception('Ungültige Etikettengröße: ${selectedLabel!.width}mm');
        }

        // Verbinde mit Drucker
        if (_activeConnectionType == 'bluetooth') {
          printInfo.port = Port.BLUETOOTH;
          List<BluetoothPrinter> bluetoothPrinters =
          await printer.getBluetoothPrinters([Model.QL_820NWB.getName()]);

          if (bluetoothPrinters.isEmpty) {
            throw Exception('Bluetooth-Drucker nicht gefunden');
          }

          printInfo.macAddress = bluetoothPrinters[0].macAddress;
        } else {
          printInfo.port = Port.NET;
          List<NetPrinter> netPrinters =
          await printer.getNetPrinters([Model.QL_820NWB.getName()]);

          if (netPrinters.isEmpty) {
            throw Exception('Netzwerk-Drucker nicht gefunden');
          }

          printInfo.ipAddress = netPrinters[0].ipAddress;
        }

        await printer.setPrinterInfo(printInfo);

        // Drucke jedes Label einzeln
        int printed = 0;
        for (var customer in selectedCustomers) {
          PrintStatus.updateStatus("Drucke Label ${printed + 1} von ${selectedCustomers.length}...");

          final pdfFile = await _generateLabelPdf(customer);
          var status = await printer.printPdfFile(pdfFile.path, 1);

          if (status.errorCode.getName() != 'ERROR_NONE') {
            throw Exception('Druckfehler: ${status.errorCode.getName()}');
          }

          printed++;

          // Kurze Pause zwischen Labels
          await Future.delayed(const Duration(milliseconds: 500));
        }

        PrintStatus.updateStatus("Druckvorgang erfolgreich abgeschlossen");
        await Future.delayed(const Duration(milliseconds: 500));

      } catch (e) {
        PrintStatus.updateStatus("Fehler: ${e.toString()}");
        await Future.delayed(const Duration(seconds: 2));
        throw e;
      }
    });
  }

  Future<File> _generateLabelPdf(Customer customer) async {
    final pdf = pw.Document();

    // Label-Dimensionen - wir verwenden eine fixe Länge für Adressen
    final labelWidth = selectedLabel!.width.toDouble();
    final labelLength = 80.0; // Feste Länge für Adressetiketten

    final pageFormat = PdfPageFormat(
      labelLength, // Länge
      labelWidth,  // Breite (Höhe des Etiketts)
      marginAll: 0,
    );

    final fontSize = _calculateFontSize();
    final addressLines = _formatAddressLines(customer);

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Container(
            padding: pw.EdgeInsets.all(labelWidth * 0.1), // Padding relativ zur Höhe
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: addressLines.map((line) => pw.Text(
                line,
                style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight: pw.FontWeight.normal,
                ),
              )).toList(),
            ),
          );
        },
      ),
    );

    try {
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/address_label_${customer.id}.pdf");
      await file.writeAsBytes(await pdf.save());
      return file;
    } catch (e) {
      print('Error creating PDF: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentCustomer = selectedCustomers.isNotEmpty
        ? selectedCustomers[currentPreviewIndex]
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adressen drucken'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: CustomerFilterService.hasActiveFilters(_activeFilters),
              label: const Text('!'),
              child: getAdaptiveIcon(
                iconName: 'filter_list',
                defaultIcon: Icons.filter_list,
              ),
            ),
            onPressed: _showFilterInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          // Label-Auswahl
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    getAdaptiveIcon(
                      iconName: 'label',
                      defaultIcon: Icons.label,
                      color: primaryAppColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Etikettenformat',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryAppColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: labelTypes.map((label) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildLabelOption(label),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Drucker-Status
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isPrinterOnline
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isPrinterOnline ? Colors.green : Colors.red,
                width: 1,
              ),
            ),
            child: Row(
              children: [

                  _isPrinterOnline ?

                getAdaptiveIcon(iconName: 'check_circle', defaultIcon: Icons.check_circle,color: Colors.green):
                  getAdaptiveIcon(iconName: 'error', defaultIcon: Icons.error, color:Colors.red,),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isPrinterOnline
                            ? 'Drucker verbunden'
                            : 'Drucker nicht verfügbar',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (_isPrinterOnline && _printerDetails != null)
                        Text(
                          _printerDetails!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!_printerSearching)
                  IconButton(
                    onPressed: _checkPrinterStatus,
                    icon: getAdaptiveIcon(
                      iconName: 'refresh',
                      defaultIcon: Icons.refresh,
                    ),
                  )
                else
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),

          // Statistik
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatistic(
                  'Ausgewählte Kunden',
                  '${selectedCustomers.length}',
                  Icons.people,
                  'people'
                ),
                _buildStatistic(
                  'Etiketten',
                  '${selectedCustomers.length}',
                  Icons.label,
                  'label'
                ),

              ],
            ),
          ),

          // Vorschau-Bereich
          Expanded(
            child: selectedCustomers.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  getAdaptiveIcon(
                    iconName: 'label_off',
                    defaultIcon: Icons.label_off,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Keine Kunden für Weihnachtskarte ausgewählt',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
                : Column(
              children: [
                // Navigation
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: currentPreviewIndex > 0
                            ? () => setState(() => currentPreviewIndex--)
                            : null,
                        icon: getAdaptiveIcon(
                          iconName: 'chevron_left',
                          defaultIcon: Icons.chevron_left,
                        ),
                      ),
                      Text(
                        'Vorschau ${currentPreviewIndex + 1} von ${selectedCustomers.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: currentPreviewIndex < selectedCustomers.length - 1
                            ? () => setState(() => currentPreviewIndex++)
                            : null,
                        icon: getAdaptiveIcon(
                          iconName: 'chevron_right',
                          defaultIcon: Icons.chevron_right,
                        ),
                      ),
                    ],
                  ),
                ),

                // Vorschau mit maßstabsgetreuer Darstellung
                if (currentCustomer != null && selectedLabel != null)
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          child: Container(
                            // Echte Größe in Pixel umgerechnet
                            width: _mmToPixels(80), // 80mm Länge für Adressetiketten
                            height: _mmToPixels(selectedLabel!.width), // Höhe ist die Breite des Etiketts
                            padding: EdgeInsets.all(_mmToPixels(selectedLabel!.width * 0.1)),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: _formatAddressLines(currentCustomer)
                                  .map((line) => Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  line,
                                  style: TextStyle(
                                    fontSize: _mmToPixels(selectedLabel!.width * 0.15), // Schriftgröße proportional
                                    height: 1.2,
                                  ),
                                ),
                              ))
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Größenangabe unter der Vorschau
                if (selectedLabel != null)
                  Text(
                    'Etikettenhöhe: ${selectedLabel!.width}mm',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: _isPrinterOnline && selectedCustomers.isNotEmpty && selectedLabel != null
                ? _printLabels
                : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: primaryAppColor,
              disabledBackgroundColor: Colors.grey.shade300,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: getAdaptiveIcon(
              iconName: 'print',
              defaultIcon: Icons.print,
              color: Colors.white,
            ),
            label: Text(
              'Alle ${selectedCustomers.length} Etiketten drucken',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabelOption(LabelType label) {
    final isSelected = selectedLabel?.id == label.id;

    return InkWell(
      onTap: () {
        setState(() {
          selectedLabel = label;
        });
        // Speichere Auswahl
        FirebaseFirestore.instance
            .collection('general_data')
            .doc('office')
            .set({
          'defaultAddressLabelWidth': label.width,
        }, SetOptions(merge: true));
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryAppColor.withOpacity(0.1)
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? primaryAppColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '${label.width}mm',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? primaryAppColor : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label.id,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? primaryAppColor : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistic(String label, String value, IconData icon,String iconName) {
    return Column(
      children: [
        getAdaptiveIcon(iconName: iconName, defaultIcon:icon, color: primaryAppColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  void _showFilterInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aktive Filter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Die Adressetiketten werden für alle Kunden gedruckt, die:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            if (CustomerFilterService.hasActiveFilters(_activeFilters)) ...[
                           const SizedBox(height: 4),
              Text(
                CustomerFilterService.getFilterSummary(_activeFilters),
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }
}

// LabelType-Klasse (falls nicht schon vorhanden)
class LabelType {
  final String id;
  final String name;
  final String description;
  final double width;
  final double height;
  final String possible_size;

  LabelType({
    required this.id,
    required this.name,
    required this.description,
    required this.width,
    required this.height,
    required this.possible_size,
  });
}