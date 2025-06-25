import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tonewood/analytics/sales/export_module.dart';
import '../../services/icon_helper.dart';
import 'export_document_service.dart';

class ExportDocumentsScreen extends StatefulWidget {
  final String receiptId;

  const ExportDocumentsScreen({
    Key? key,
    required this.receiptId,
  }) : super(key: key);

  @override
  _ExportDocumentsScreenState createState() => _ExportDocumentsScreenState();
}

class _ExportDocumentsScreenState extends State<ExportDocumentsScreen> {
  bool _isLoading = true;
  bool _error = false;
  String _errorMessage = '';
  Map<String, dynamic>? _receiptData;
  Map<String, dynamic>? _customerData;


  // Form controllers
  final TextEditingController _containerNumberController = TextEditingController();
  final TextEditingController _sealNumberController = TextEditingController();
  final TextEditingController _customerVatController = TextEditingController();
  final TextEditingController _deliveryDateController = TextEditingController();
  final TextEditingController _transporterController = TextEditingController();
  final TextEditingController _invoiceNumberController = TextEditingController();

  // Dropdown values
  String _selectedIncoterm = 'EXW';
  String _selectedTransportType = 'Strassentransport';
  String _selectedExportPurpose = 'Handelswaren';

  @override
  void initState() {
    super.initState();
    _loadReceiptData();

    // Initialize with default values
    _deliveryDateController.text = DateFormat('dd.MM.yyyy').format(
        DateTime.now().add(const Duration(days: 14))
    );
  }

  @override
  void dispose() {
    _containerNumberController.dispose();
    _sealNumberController.dispose();
    _customerVatController.dispose();
    _deliveryDateController.dispose();
    _transporterController.dispose();
    _invoiceNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadReceiptData() async {
    setState(() {
      _isLoading = true;
      _error = false;
    });

    try {
      final receiptDoc = await FirebaseFirestore.instance
          .collection('sales_receipts')
          .doc(widget.receiptId)
          .get();

      if (!receiptDoc.exists) {
        setState(() {
          _isLoading = false;
          _error = true;
          _errorMessage = 'Der Beleg existiert nicht.';
        });
        return;
      }

      final data = receiptDoc.data()!;
      setState(() {
        _receiptData = data;
        _customerData = data['customer'] as Map<String, dynamic>;
        _isLoading = false;

        // Set default invoice number (if receipt has a number)
        final receiptNumber = data['receiptNumber'] as String?;
        if (receiptNumber != null) {
          _invoiceNumberController.text = '${DateTime.now().year}-$receiptNumber';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = true;
        _errorMessage = 'Fehler beim Laden der Daten: $e';
      });
    }
  }

  Future<void> _generateAndDownloadDocuments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Sammle alle Formular-Daten in einem Map
      final Map<String, dynamic> exportInfo = {
        'containerNumber': _containerNumberController.text.trim(),
        'sealNumber': _sealNumberController.text.trim(),
        'customerVat': _customerVatController.text.trim(),
        'deliveryDate': _deliveryDateController.text.trim(),
        'transportType': _selectedTransportType,
        'transporter': _transporterController.text.trim(),
        'incoterm': _selectedIncoterm,
        'exportPurpose': _selectedExportPurpose,
        'invoiceNumber': _invoiceNumberController.text.trim(),
      };

      // Nutze das ExportModule für die Generierung und Speicherung der Dokumente
      final result = await ExportModule.generateAndSaveExportDocuments(
        receiptId: widget.receiptId,
        exportInfo: exportInfo,
        saveToDrive: true, // Speichere die Dokumente in Firebase Storage
      );

      if (result['status'] == 'success') {
        // Dokumente wurden erfolgreich generiert und gespeichert
        final invoiceUrl = result['invoiceUrl'];
        final packingListUrl = result['packingListUrl'];

        // Je nach Plattform Dokumente herunterladen oder teilen
        if (kIsWeb) {
          // Für Web-Plattform: Zeige Links zum Herunterladen an
          final invoiceBytes = await ExportDocumentsService.generateCommercialInvoice(
            widget.receiptId,
          );

          final containerInfo = _containerNumberController.text.isNotEmpty &&
              _sealNumberController.text.isNotEmpty
              ? '${_containerNumberController.text}, seal ${_sealNumberController.text}'
              : null;

          final packingListBytes = await ExportDocumentsService.generatePackingList(
            widget.receiptId,
            containerInfo: containerInfo,
          );

          await ExportDocumentsService.downloadSingleFile(
              invoiceBytes,
              'CommercialInvoice_${widget.receiptId}.pdf'
          );
          await ExportDocumentsService.downloadSingleFile(
              packingListBytes,
              'PackingList_${widget.receiptId}.pdf'
          );
        } else {
          // Für mobile Geräte: Teile die Dokumente direkt
          final invoiceBytes = await ExportDocumentsService.generateCommercialInvoice(
            widget.receiptId,
          );

          final containerInfo = _containerNumberController.text.isNotEmpty &&
              _sealNumberController.text.isNotEmpty
              ? '${_containerNumberController.text}, seal ${_sealNumberController.text}'
              : null;

          final packingListBytes = await ExportDocumentsService.generatePackingList(
            widget.receiptId,
            containerInfo: containerInfo,
          );

          // Für mobile Geräte
          final tempDir = await getTemporaryDirectory();

          // Handelsrechnung speichern
          final invoiceFile = File('${tempDir.path}/CommercialInvoice_${widget.receiptId}.pdf');
          await invoiceFile.writeAsBytes(invoiceBytes);

          // Packliste speichern
          final packingListFile = File('${tempDir.path}/PackingList_${widget.receiptId}.pdf');
          await packingListFile.writeAsBytes(packingListBytes);

          // Beide Dateien teilen
          await Share.shareXFiles(
            [
              XFile(invoiceFile.path),
              XFile(packingListFile.path),
            ],
            subject: 'Export Documents for Order ${widget.receiptId}',
          );
        }

        // Erfolgs-Meldung anzeigen
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dokumente wurden erfolgreich erstellt und heruntergeladen'),
              backgroundColor: Colors.green,
            ),
          );

          setState(() {
            _isLoading = false;
          });

          // Dialog schließen und Erfolg zurückgeben
          Navigator.pop(context, true);
        }
      } else {
        // Fehler bei der Dokumentenerstellung
        throw Exception(result['error'] ?? 'Unbekannter Fehler bei der Dokumentenerstellung');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = true;
          _errorMessage = 'Fehler beim Erstellen der Dokumente: $e';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $_errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exportdokumente'),
        actions: [
          if (!_isLoading && !_error)
            IconButton(
              icon: getAdaptiveIcon(iconName: 'download', defaultIcon: Icons.download),
              tooltip: 'Dokumente erstellen',
              onPressed: _generateAndDownloadDocuments,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            getAdaptiveIcon(iconName: 'error', defaultIcon: Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadReceiptData,
              child: const Text('Erneut versuchen'),
            ),
          ],
        ),
      );
    }

    if (_receiptData == null || _customerData == null) {
      return const Center(child: Text('Keine Daten gefunden'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCustomerSection(),
          const SizedBox(height: 24),
          _buildExportDetailsSection(),
          const SizedBox(height: 24),
          _buildPackagingSection(),
          const SizedBox(height: 32),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildCustomerSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                getAdaptiveIcon(iconName: 'person', defaultIcon: Icons.person),
                const SizedBox(width: 8),
                const Text(
                  'Kunde',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Customer details
            Text(
              '${_customerData!['company'] ?? 'Unbekannte Firma'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('${_customerData!['fullName'] ?? ''}'),
            Text('${_customerData!['street'] ?? ''} ${_customerData!['houseNumber'] ?? ''}'),
            Text('${_customerData!['zipCode'] ?? ''} ${_customerData!['city'] ?? ''}'),
            Text('${_customerData!['country'] ?? ''}'),
            const SizedBox(height: 8),
            Text('E-Mail: ${_customerData!['email'] ?? ''}'),

            const SizedBox(height: 16),

            // Customer VAT number input
            TextFormField(
              controller: _customerVatController,
              decoration: const InputDecoration(
                labelText: 'VAT/EORI-Nummer des Kunden',
                border: OutlineInputBorder(),
                hintText: 'z.B. DE123456789',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportDetailsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                getAdaptiveIcon(iconName: 'info', defaultIcon: Icons.info),
                const SizedBox(width: 8),
                const Text(
                  'Exportdetails',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Invoice number
            TextFormField(
              controller: _invoiceNumberController,
              decoration: const InputDecoration(
                labelText: 'Rechnungsnummer',
                border: OutlineInputBorder(),
                hintText: 'z.B. 2025-5472',
              ),
            ),
            const SizedBox(height: 16),

            // Delivery date
            TextFormField(
              controller: _deliveryDateController,
              decoration: InputDecoration(
                labelText: 'Lieferdatum',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: getAdaptiveIcon(iconName: 'calendar_today', defaultIcon: Icons.calendar_today),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 14)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );

                    if (date != null) {
                      _deliveryDateController.text = DateFormat('dd.MM.yyyy').format(date);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Incoterm dropdown
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Incoterm 2020',
                border: OutlineInputBorder(),
              ),
              value: _selectedIncoterm,
              items: const [
                DropdownMenuItem(value: 'EXW', child: Text('EXW - Ab Werk')),
                DropdownMenuItem(value: 'FCA', child: Text('FCA - Frei Frachtführer')),
                DropdownMenuItem(value: 'CPT', child: Text('CPT - Frachtfrei')),
                DropdownMenuItem(value: 'CIP', child: Text('CIP - Frachtfrei versichert')),
                DropdownMenuItem(value: 'DAP', child: Text('DAP - Geliefert benannter Ort')),
                DropdownMenuItem(value: 'DPU', child: Text('DPU - Geliefert entladen')),
                DropdownMenuItem(value: 'DDP', child: Text('DDP - Geliefert verzollt')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedIncoterm = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Export purpose dropdown
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Grund für Export',
                border: OutlineInputBorder(),
              ),
              value: _selectedExportPurpose,
              items: const [
                DropdownMenuItem(value: 'Handelswaren', child: Text('Handelswaren')),
                DropdownMenuItem(value: 'Muster', child: Text('Muster')),
                DropdownMenuItem(value: 'Geschenk', child: Text('Geschenk')),
                DropdownMenuItem(value: 'Rücksendung', child: Text('Rücksendung')),
                DropdownMenuItem(value: 'Reparatur', child: Text('Reparatur')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedExportPurpose = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Transport type dropdown with transporter
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Transportart',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedTransportType,
                    items: const [
                      DropdownMenuItem(value: 'Strassentransport', child: Text('Strassentransport')),
                      DropdownMenuItem(value: 'Luftfracht', child: Text('Luftfracht')),
                      DropdownMenuItem(value: 'Seefracht', child: Text('Seefracht')),
                      DropdownMenuItem(value: 'Schweizer Post', child: Text('Schweizer Post')),
                      DropdownMenuItem(value: 'Kurier', child: Text('Kurier')),
                      DropdownMenuItem(value: 'Selbstabholung', child: Text('Selbstabholung')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedTransportType = value;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _transporterController,
                    decoration: const InputDecoration(
                      labelText: 'Spedition/Frachtführer',
                      border: OutlineInputBorder(),
                      hintText: 'z.B. DHL, UPS, etc.',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackagingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                getAdaptiveIcon(iconName: 'inventory', defaultIcon: Icons.inventory),
                const SizedBox(width: 8),
                const Text(
                  'Verpackungsdetails',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Container number and seal
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _containerNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Container-Nr.',
                      border: OutlineInputBorder(),
                      hintText: 'z.B. BSIU 245144-3',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _sealNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Plomben-Nr.',
                      border: OutlineInputBorder(),
                      hintText: 'z.B. 051219',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Package details - this would be more dynamic in a real implementation
            // For this prototype, just showing summary of items in receipt
            Text(
              'Bestellte Artikel: ${(_receiptData!['items'] as List).length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Die Packstücke werden basierend auf den Artikeln automatisch generiert. '
                  'In der PDF-Vorschau können Sie die Details überprüfen und anpassen.',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Abbrechen'),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _generateAndDownloadDocuments,
          icon: _isLoading
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : getAdaptiveIcon(iconName: 'file_download', defaultIcon: Icons.file_download),
          label: const Text('Dokumente erstellen'),
        ),
      ],
    );
  }
}