

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:tonewood/home/warehouse_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:share_plus/share_plus.dart';
import '../constants.dart';
import '../services/cost_center.dart';
import '../services/customer.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:intl/intl.dart';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

import 'dart:typed_data';

import '../services/discount.dart';
import '../services/download_helper_mobile.dart' if (dart.library.html) '../services/download_helper_web.dart';
import '../services/fair_management_screen.dart';
import '../services/fairs.dart';

import 'package:csv/csv.dart';
class SalesScreen extends StatefulWidget {
const SalesScreen({Key? key}) : super(key: key);

@override
SalesScreenState createState() => SalesScreenState();
}

class SalesScreenState extends State<SalesScreen> {
  Fair? selectedFair;
  final ValueNotifier<Fair?> _selectedFairNotifier = ValueNotifier<Fair?>(null);
bool isLoading = false;
final TextEditingController barcodeController = TextEditingController();
final TextEditingController quantityController = TextEditingController();
Customer? selectedCustomer;
final TextEditingController customerSearchController = TextEditingController();
final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(true);
CostCenter? selectedCostCenter;
Map<String, dynamic>? selectedProduct;
// Füge diese Variablen zur SalesScreenState-Klasse hinzu
  bool sendPdfToCustomer = true;
  bool sendCsvToCustomer = false;
  bool sendPdfToOffice = true;
  bool sendCsvToOffice = true;

Stream<QuerySnapshot> get _basketStream => FirebaseFirestore.instance
    .collection('temporary_basket')
    .orderBy('timestamp', descending: true)
    .snapshots();



@override
Widget build(BuildContext context) {
final screenWidth = MediaQuery.of(context).size.width;
final isDesktopLayout = screenWidth > ResponsiveBreakpoints.tablet;

return Scaffold(
    appBar:
    AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Kunde - mit roter "Kunde wählen" Anzeige wenn kein Kunde ausgewählt
          StreamBuilder<Customer?>(
            stream: _temporaryCustomerStream,
            builder: (context, snapshot) {
              final customer = snapshot.data;

              return GestureDetector(
                onTap: _showCustomerSelection,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: customer != null
                        ? Theme.of(context).colorScheme.secondaryContainer
                        : Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person,
                        size: 14,
                        color: customer != null
                            ? Theme.of(context).colorScheme.onSecondaryContainer
                            : Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        customer != null
                            ? customer.company.substring(0, min(2, customer.company.length)).toUpperCase()
                            : 'Kunde wählen',
                        style: TextStyle(
                          color: customer != null
                              ? Theme.of(context).colorScheme.onSecondaryContainer
                              : Theme.of(context).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 6),

          // Kostenstelle - bleibt unverändert
          StreamBuilder<CostCenter?>(
            stream: _temporaryCostCenterStream,
            builder: (context, snapshot) {
              final costCenter = snapshot.data;

              return GestureDetector(
                onTap: _showCostCenterSelection,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: costCenter != null
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_balance,
                        size: 14,
                        color: costCenter != null
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 4),
                      if (costCenter != null)
                        Tooltip(
                          message: '${costCenter.code} - ${costCenter.name}',
                          child: Text(
                            costCenter.code,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 6),

          // Messe - bleibt unverändert
          StreamBuilder<Fair?>(
            stream: _temporaryFairStream,
            builder: (context, snapshot) {
              final fair = snapshot.data;
              if (fair == null) return const SizedBox.shrink();

              return GestureDetector(
                onTap: _showFairSelection,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.event,
                        size: 14,
                        color: Theme.of(context).colorScheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: fair.name,
                        child: Text(
                          fair.name.substring(0, min(2, fair.name.length)).toUpperCase(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      actions: [
        // Messe-Icon
        Tooltip(
          message: 'Messe',
          child: IconButton(
            icon: const Icon(Icons.event),
            onPressed: _showFairSelection,
          ),
        ),

        // Email-Icon
        IconButton(
          icon: const Icon(Icons.email),
          tooltip: 'Email-Konfiguration',
          onPressed: _showEmailConfigDialog,
        ),
      ],
    ),
    // AppBar(
    //   title: Row(
    //     mainAxisSize: MainAxisSize.min,
    //     children: [
    //       // Kunde
    //       StreamBuilder<Customer?>(
    //         stream: _temporaryCustomerStream,
    //         builder: (context, snapshot) {
    //           final customer = snapshot.data;
    //           if (customer == null) return const SizedBox.shrink();
    //
    //           return GestureDetector(
    //             onTap: _showCustomerSelection,
    //             child: Container(
    //               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    //               decoration: BoxDecoration(
    //                 color: Theme.of(context).colorScheme.secondaryContainer,
    //                 borderRadius: BorderRadius.circular(12),
    //               ),
    //               child: Row(
    //                 mainAxisSize: MainAxisSize.min,
    //                 children: [
    //                   Icon(
    //                     Icons.person,
    //                     size: 14,
    //                     color: Theme.of(context).colorScheme.onSecondaryContainer,
    //                   ),
    //                   const SizedBox(width: 4),
    //                   Tooltip(
    //                     message: customer.company,
    //                     child: Text(
    //                       customer.company.substring(0, min(2, customer.company.length)).toUpperCase(),
    //                       style: TextStyle(
    //                         color: Theme.of(context).colorScheme.onSecondaryContainer,
    //                         fontWeight: FontWeight.bold,
    //                         fontSize: 13,
    //                       ),
    //                     ),
    //                   ),
    //                 ],
    //               ),
    //             ),
    //           );
    //         },
    //       ),
    //       const SizedBox(width: 6),
    //
    //       StreamBuilder<CostCenter?>(
    //         stream: _temporaryCostCenterStream,
    //         builder: (context, snapshot) {
    //           final costCenter = snapshot.data;
    //
    //           return GestureDetector(
    //             onTap: _showCostCenterSelection,
    //             child: Container(
    //               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    //               decoration: BoxDecoration(
    //                 color: costCenter != null
    //                     ? Theme.of(context).colorScheme.primaryContainer
    //                     : Theme.of(context).colorScheme.errorContainer,
    //                 borderRadius: BorderRadius.circular(12),
    //               ),
    //               child: Row(
    //                 mainAxisSize: MainAxisSize.min,
    //                 children: [
    //                   Icon(
    //                     Icons.account_balance,
    //                     size: 14,
    //                     color: costCenter != null
    //                         ? Theme.of(context).colorScheme.onPrimaryContainer
    //                         : Theme.of(context).colorScheme.onErrorContainer,
    //                   ),
    //                   const SizedBox(width: 4),
    //                   if (costCenter != null)
    //                     Tooltip(
    //                       message: '${costCenter.code} - ${costCenter.name}',
    //                       child: Text(
    //                         costCenter.code,
    //                         style: TextStyle(
    //                           color: Theme.of(context).colorScheme.onPrimaryContainer,
    //                           fontSize: 11,
    //                           fontWeight: FontWeight.bold,
    //                         ),
    //                       ),
    //                     ),
    //                 ],
    //               ),
    //             ),
    //           );
    //         },
    //       ),
    //       const SizedBox(width: 6),
    //
    //       StreamBuilder<Fair?>(
    //         stream: _temporaryFairStream,
    //         builder: (context, snapshot) {
    //           final fair = snapshot.data;
    //           if (fair == null) return const SizedBox.shrink();
    //
    //           return GestureDetector(
    //             onTap: _showFairSelection,
    //             child: Container(
    //               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    //               decoration: BoxDecoration(
    //                 color: Theme.of(context).colorScheme.tertiaryContainer,
    //                 borderRadius: BorderRadius.circular(12),
    //               ),
    //               child: Row(
    //                 mainAxisSize: MainAxisSize.min,
    //                 children: [
    //                   Icon(
    //                     Icons.event,
    //                     size: 14,
    //                     color: Theme.of(context).colorScheme.onTertiaryContainer,
    //                   ),
    //                   const SizedBox(width: 4),
    //                   Tooltip(
    //                     message: fair.name,
    //                     child: Text(
    //                       fair.name.substring(0, min(2, fair.name.length)).toUpperCase(),
    //                       style: TextStyle(
    //                         color: Theme.of(context).colorScheme.onTertiaryContainer,
    //                         fontWeight: FontWeight.bold,
    //                         fontSize: 13,
    //                       ),
    //                     ),
    //                   ),
    //                 ],
    //               ),
    //             ),
    //           );
    //         },
    //       ),
    //     ],
    //   ),
    //   actions: [
    //     if (!isDesktopLayout)
    //       StreamBuilder<Customer?>(
    //         stream: _temporaryCustomerStream,
    //         builder: (context, snapshot) {
    //           final hasCustomer = snapshot.hasData;
    //           return Tooltip(
    //             message: hasCustomer ? 'Kunde ändern' : 'Kunde auswählen',
    //             child: IconButton(
    //               icon: Icon(
    //                 hasCustomer ? Icons.person : Icons.person_add,
    //                 color: hasCustomer
    //                     ? Theme.of(context).colorScheme.primary
    //                     : null,
    //               ),
    //               onPressed: _showCustomerSelection,
    //             ),
    //           );
    //         },
    //       ),
    //
    //     StreamBuilder<CostCenter?>(
    //       stream: _temporaryCostCenterStream,
    //       builder: (context, snapshot) {
    //         final hasCostCenter = snapshot.hasData;
    //         return Tooltip(
    //           message: 'Kostenstelle auswählen',
    //           child: IconButton(
    //             icon: Icon(
    //               Icons.account_balance,
    //               color: !hasCostCenter
    //                   ? Theme.of(context).colorScheme.error
    //                   : Theme.of(context).colorScheme.primary,
    //             ),
    //             onPressed: _showCostCenterSelection,
    //           ),
    //         );
    //       },
    //     ),
    //
    //     Tooltip(
    //       message: 'Messe auswählen',
    //       child: IconButton(
    //         icon: const Icon(Icons.event),
    //         onPressed: _showFairSelection,
    //       ),
    //     ),
    //
    //
    //       IconButton(
    //         icon: const Icon(Icons.email),
    //         tooltip: 'Email-Konfiguration',
    //         onPressed: _showEmailConfigDialog,
    //       ),
    //   ],
    // ),


  body: isDesktopLayout ? _buildDesktopLayout() : _buildMobileLayout(),
);
}

// Stream für die Büro-Email
  Stream<String> get _officeEmailStream => FirebaseFirestore.instance
      .collection('general_data')
      .doc('office')
      .snapshots()
      .map((snapshot) => snapshot.data()?['email'] as String? ?? 'keine Email hinterlegt');

  Stream<Map<String, dynamic>> get _officeSettingsStream => FirebaseFirestore.instance
      .collection('general_data')
      .doc('office')
      .snapshots()
      .map((snapshot) => snapshot.data() ?? {});


  // Füge diese Methode zur SalesScreenState-Klasse hinzu
  void _showEmailConfigDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Scaffold(
                resizeToAvoidBottomInset: false,
                body: StreamBuilder<Map<String, dynamic>>(
                  stream: _officeSettingsStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final settings = snapshot.data!;
                      sendPdfToCustomer = settings['sendPdfToCustomer'] ?? true;
                      sendCsvToCustomer = settings['sendCsvToCustomer'] ?? false;
                      sendPdfToOffice = settings['sendPdfToOffice'] ?? true;
                      sendCsvToOffice = settings['sendCsvToOffice'] ?? true;
                    }

                    return Column(
                      children: [
                        // Header - Fixed at top
                        Row(
                          children: [
                            const Icon(Icons.email, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'Email',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Scrollable content
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Kundenbereich
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Email an Kunden',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      StreamBuilder<Customer?>(
                                        stream: _temporaryCustomerStream,
                                        builder: (context, snapshot) {
                                          final customer = snapshot.data;
                                          return Text(
                                            customer?.email ?? 'Kein Kunde ausgewählt',
                                            style: TextStyle(
                                              color: customer == null
                                                  ? Theme.of(context).colorScheme.error
                                                  : Theme.of(context).colorScheme.onSurface,
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      CheckboxListTile(
                                        title: const Text('PDF anhängen', style: TextStyle(fontSize: 14,)),
                                        value: sendPdfToCustomer,
                                        onChanged: (value) async {
                                          setState(() => sendPdfToCustomer = value ?? false);
                                          await _saveOfficeSettings({
                                            'sendPdfToCustomer': value,
                                          });
                                        },
                                      ),
                                      CheckboxListTile(
                                        title: const Text('CSV anhängen', style: TextStyle(fontSize: 14,)),
                                        value: sendCsvToCustomer,
                                        onChanged: (value) async {
                                          setState(() => sendCsvToCustomer = value ?? false);
                                          await _saveOfficeSettings({
                                            'sendCsvToCustomer': value,
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Bürobereich
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Email ans Büro',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      StreamBuilder<String>(
                                        stream: _officeEmailStream,
                                        builder: (context, snapshot) {
                                          return Row(
                                            children: [
                                              Expanded(
                                                child: Text(snapshot.data ?? 'Lädt...'),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.edit),
                                                onPressed: () => _showEditOfficeEmailDialog(context),
                                                tooltip: 'Büro-Email bearbeiten',
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      CheckboxListTile(
                                        title: const Text('PDF anhängen', style: TextStyle(fontSize: 14,)),
                                        value: sendPdfToOffice,
                                        onChanged: (value) async {
                                          setState(() => sendPdfToOffice = value ?? false);
                                          await _saveOfficeSettings({
                                            'sendPdfToOffice': value,
                                          });
                                        },
                                      ),
                                      CheckboxListTile(
                                        title: const Text('CSV anhängen', style: TextStyle(fontSize: 14,)),
                                        value: sendCsvToOffice,
                                        onChanged: (value) async {
                                          setState(() => sendCsvToOffice = value ?? false);
                                          await _saveOfficeSettings({
                                            'sendCsvToOffice': value,
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Footer - Fixed at bottom
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 24.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Schließen'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveOfficeSettings(Map<String, dynamic> updates) async {
    try {
      await FirebaseFirestore.instance
          .collection('general_data')
          .doc('office')
          .set(updates, SetOptions(merge: true));
    } catch (e) {
      print('Fehler beim Speichern der Einstellungen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  void _showEditOfficeEmailDialog(BuildContext context) {
    final emailController = TextEditingController();

    // Aktuelle Email laden
    FirebaseFirestore.instance
        .collection('general_data')
        .doc('office')
        .get()
        .then((doc) {
      if (doc.exists) {
        emailController.text = doc.data()?['email'] ?? '';
      }
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Büro-Email bearbeiten'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email-Adresse',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Bitte Email-Adresse eingeben';
                }
                if (!value.contains('@')) {
                  return 'Bitte gültige Email-Adresse eingeben';
                }
                return null;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.isNotEmpty && emailController.text.contains('@')) {
                try {
                  await FirebaseFirestore.instance
                      .collection('general_data')
                      .doc('office')
                      .set({
                    'email': emailController.text.trim(),
                    'last_modified': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Email-Adresse wurde aktualisiert'),
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
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }
// Füge diese Methode zur SalesScreenState-Klasse hinzu

  // In deiner sales_screen.dart

  Future<void> _sendConfiguredEmails(
      String receiptId,
      Uint8List pdfBytes,
      Uint8List? csvBytes,
      Map<String, dynamic> receiptData,
      ) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable('sendEmail');

      final customer = Customer.fromMap(
        receiptData['customer'] as Map<String, dynamic>,
        '',
      );

      // Hole die Office-Einstellungen
      final officeDoc = await FirebaseFirestore.instance
          .collection('general_data')
          .doc('office')
          .get();

      final officeSettings = officeDoc.data() ?? {};

      print('Office Settings: $officeSettings'); // Debug

      // Email an Kunden
      if ((officeSettings['sendPdfToCustomer'] == true ||
          officeSettings['sendCsvToCustomer'] == true) &&
          customer.email.isNotEmpty) {
        try {
          print('Preparing customer email attachments...'); // Debug

          final attachments = <Map<String, String>>[];

          if (officeSettings['sendPdfToCustomer'] == true && pdfBytes != null) {
            print('Adding PDF for customer (${pdfBytes.length} bytes)'); // Debug
            attachments.add({
              'filename': 'Lieferschein_$receiptId.pdf',
              'content': base64Encode(pdfBytes),
              'encoding': 'base64',
            });
          }

          if (officeSettings['sendCsvToCustomer'] == true && csvBytes != null) {
            print('Adding CSV for customer (${csvBytes.length} bytes)'); // Debug
            attachments.add({
              'filename': 'Bestellung_$receiptId.csv',
              'content': base64Encode(csvBytes),
              'encoding': 'base64',
            });
          }

          print('Sending customer email with ${attachments.length} attachments...'); // Debug

          final result = await callable.call({
            'to': customer.email,
            'subject': 'Ihre Bestellung bei Tonewood Switzerland',
            'html': '''
            <p>Sehr geehrte Damen und Herren,</p>
            <p>vielen Dank für Ihren Einkauf bei Tonewood Switzerland.</p>
            <p>Im Anhang finden Sie die gewünschten Dokumente zu Ihrer Bestellung.</p>
            <p>Mit freundlichen Grüßen<br>Ihr Tonewood Switzerland Team</p>
          ''',
            'attachments': attachments,
          });

          print('Customer email result: ${result.data}'); // Debug
        } catch (e) {
          print('Error sending customer email: $e');
          rethrow;
        }
      }

      // Email ans Büro
      final officeEmail = officeDoc.data()?['email'];
      if (officeEmail != null &&
          (officeSettings['sendPdfToOffice'] == true ||
              officeSettings['sendCsvToOffice'] == true)) {
        try {
          print('Preparing office email attachments...'); // Debug

          final attachments = <Map<String, String>>[];

          if (officeSettings['sendPdfToOffice'] == true && pdfBytes != null) {
            print('Adding PDF for office (${pdfBytes.length} bytes)'); // Debug
            attachments.add({
              'filename': 'Lieferschein_$receiptId.pdf',
              'content': base64Encode(pdfBytes),
              'encoding': 'base64',
            });
          }

          if (officeSettings['sendCsvToOffice'] == true && csvBytes != null) {
            print('Adding CSV for office (${csvBytes.length} bytes)'); // Debug
            attachments.add({
              'filename': 'Bestellung_$receiptId.csv',
              'content': base64Encode(csvBytes),
              'encoding': 'base64',
            });
          }

          print('Sending office email with ${attachments.length} attachments...'); // Debug

          final result = await callable.call({
            'to': officeEmail,
            'subject': 'Neue Bestellung: ${customer.company}',
            'html': '''
            <h2>Neue Bestellung eingegangen</h2>
            <p><strong>Kunde:</strong> ${customer.company}<br>
            <strong>Kontakt:</strong> ${customer.fullName}<br>
            <strong>Adresse:</strong> ${customer.fullAddress}<br>
            <strong>Email:</strong> ${customer.email}</p>
            <p>Die Dokumente finden Sie im Anhang.</p>
            <p>Mit freundlichen Grüßen<br>Ihr Verkaufssystem</p>
          ''',
            'attachments': attachments,
          });

          print('Office email result: ${result.data}'); // Debug
        } catch (e) {
          print('Error sending office email: $e');
          rethrow;
        }
      }
    } catch (e) {
      print('Error in _sendConfiguredEmails: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Email-Versand: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Stream<Fair?> get _temporaryFairStream => FirebaseFirestore.instance
      .collection('temporary_fair')
      .limit(1)
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isEmpty) return null;
    return Fair.fromMap(
      snapshot.docs.first.data(),
      snapshot.docs.first.id,
    );
  });

// Methode zum Speichern der temporären Messe
  Future<void> _saveTemporaryFair(Fair fair) async {
    try {
      // Lösche vorherige temporäre Messe
      final tempDocs = await FirebaseFirestore.instance
          .collection('temporary_fair')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in tempDocs.docs) {
        batch.delete(doc.reference);
      }

      // Füge neue temporäre Messe hinzu
      batch.set(
        FirebaseFirestore.instance.collection('temporary_fair').doc(fair.id),
        {
          ...fair.toMap(),
          'timestamp': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();
    } catch (e) {
      print('Fehler beim Speichern der temporären Messe: $e');
    }
  }

// Methode zum Löschen der temporären Messe
  Future<void> _clearTemporaryFair() async {
    try {
      final tempDocs = await FirebaseFirestore.instance
          .collection('temporary_fair')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in tempDocs.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      print('Fehler beim Löschen der temporären Messe: $e');
    }
  }
  void _showFairSelection() {
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              body: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Messe',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: searchController,
                    decoration: InputDecoration(
                      labelText: 'Suchen',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('fairs')
                          .where('endDate', isGreaterThanOrEqualTo: DateTime.now().toIso8601String())
                          .orderBy('endDate')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Fehler beim Laden der Messen',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final fairs = snapshot.data?.docs
                            .map((doc) => Fair.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                            .toList() ?? [];

                        final searchTerm = searchController.text.toLowerCase();
                        final filteredFairs = fairs.where((fair) =>
                        fair.name.toLowerCase().contains(searchTerm) ||
                            fair.city.toLowerCase().contains(searchTerm) ||
                            fair.country.toLowerCase().contains(searchTerm)
                        ).toList();

                        if (filteredFairs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.event_busy,
                                  size: 48,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Keine aktiven Messen gefunden',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return StreamBuilder<Fair?>(
                          stream: _temporaryFairStream,
                          builder: (context, selectedSnapshot) {
                            return ListView.builder(
                              itemCount: filteredFairs.length,
                              itemBuilder: (context, index) {
                                final fair = filteredFairs[index];
                                final isSelected = selectedSnapshot.data?.id == fair.id;

                                return Card(
                                  elevation: isSelected ? 2 : 0,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primaryContainer
                                      : null,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isSelected
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                                      child: Icon(
                                        Icons.event,
                                        color: isSelected
                                            ? Theme.of(context).colorScheme.onPrimary
                                            : Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    title: Text(
                                      fair.name,
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.bold : null,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${fair.city}, ${fair.country}\n'
                                          '${DateFormat('dd.MM.yyyy').format(fair.startDate)} - '
                                          '${DateFormat('dd.MM.yyyy').format(fair.endDate)}',
                                    ),
                                    isThreeLine: true,
                                    onTap: () async {
                                      try {
                                        setState(() => selectedFair = fair);
                                        await _saveTemporaryFair(fair);
                                        if (mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Messe ausgewählt'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        print('Fehler beim Speichern der Messe: $e');
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Fehler: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SafeArea(
                    child: Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const FairManagementScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.settings),
                          label: const Text('Messen verwalten'),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () async {
                                try {
                                  setState(() => selectedFair = null);
                                  await _clearTemporaryFair();
                                  if (mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Messe-Auswahl zurückgesetzt'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  print('Fehler beim Zurücksetzen der Messe: $e');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Fehler: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              child: const Text('Keine Messe (Standard)'),
                            ),

                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  // Stream für die temporäre Kostenstelle
  Stream<CostCenter?> get _temporaryCostCenterStream => FirebaseFirestore.instance
      .collection('temporary_cost_center')
      .limit(1)
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isEmpty) return null;
    return CostCenter.fromMap(
      snapshot.docs.first.data(),
      snapshot.docs.first.id,
    );
  });
  void _showWarehouseDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Scaffold(
                // appBar: AppBar(
                //   title: const Text('Lager durchsuchen'),
                //   automaticallyImplyLeading: false,
                //   actions: [
                //     IconButton(
                //       icon: const Icon(Icons.close),
                //       onPressed: () => Navigator.pop(context),
                //     ),
                //   ],
                // ),
                body: WarehouseScreen(
                  key: UniqueKey(),
                  isDialog: true,
                  onBarcodeSelected: (barcode) {
                    Navigator.pop(context);
                    _fetchProductAndShowQuantityDialog(barcode);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  // Methode zum Speichern der temporären Kostenstelle
  Future<void> _saveTemporaryCostCenter(CostCenter costCenter) async {
    try {
      // Lösche vorherige temporäre Kostenstelle
      final tempDocs = await FirebaseFirestore.instance
          .collection('temporary_cost_center')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in tempDocs.docs) {
        batch.delete(doc.reference);
      }

      // Füge neue temporäre Kostenstelle hinzu
      batch.set(
        FirebaseFirestore.instance.collection('temporary_cost_center').doc(),
        {
          ...costCenter.toMap(),
          'timestamp': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();
    } catch (e) {
      print('Fehler beim Speichern der temporären Kostenstelle: $e');
    }
  }

  // Methode zum Anzeigen des Kostenstellen-Dialogs
  void _showCostCenterSelection() {
    final searchController = TextEditingController();


    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              body: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Kostenstelle',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: searchController,
                    decoration: InputDecoration(
                      labelText: 'Suchen',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('cost_centers')
                          .orderBy('code')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Fehler: ${snapshot.error}'),
                          );
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final costCenters = snapshot.data?.docs
                            .map((doc) => CostCenter.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                            .toList() ?? [];

                        final searchTerm = searchController.text.toLowerCase();
                        final filteredCostCenters = costCenters.where((cc) =>
                        cc.code.toLowerCase().contains(searchTerm) ||
                            cc.name.toLowerCase().contains(searchTerm) ||
                            cc.description.toLowerCase().contains(searchTerm)
                        ).toList();

                        if (filteredCostCenters.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.account_balance,
                                  size: 48,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Keine Kostenstellen gefunden',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: filteredCostCenters.length,
                          itemBuilder: (context, index) {
                            final costCenter = filteredCostCenters[index];
                            final isSelected = selectedCostCenter?.id == costCenter.id;

                            return Card(
                              elevation: isSelected ? 2 : 0,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : null,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                                  child: Text(
                                    costCenter.code.substring(0, 2),
                                    style: TextStyle(
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.onPrimary
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  '${costCenter.code} - ${costCenter.name}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : null,
                                  ),
                                ),
                                subtitle: Text(costCenter.description,style:TextStyle(
                                  fontSize: 12,

                                ),),
                                onTap: () async {
                                  await _saveTemporaryCostCenter(costCenter);
                                  if (mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Kostenstelle ausgewählt'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Abbrechen'),
                        ),

                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }



  Future<String> _getNextReceiptNumber() async {
    try {
      // Transaktion um Race Conditions zu vermeiden
      DocumentReference counterRef = FirebaseFirestore.instance
          .collection('general_data')
          .doc('counters');

      return await FirebaseFirestore.instance.runTransaction<String>((transaction) async {
        DocumentSnapshot counterDoc = await transaction.get(counterRef);

        int currentNumber;
        if (!counterDoc.exists || !(counterDoc.data() as Map<String, dynamic>).containsKey('lastReceiptNumber')) {
          currentNumber = 1;
        } else {
          currentNumber = (counterDoc.data() as Map<String, dynamic>)['lastReceiptNumber'] + 1;
        }

        transaction.set(counterRef, {
          'lastReceiptNumber': currentNumber,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        return currentNumber.toString().padLeft(6, '0');
      });
    } catch (e) {
      print('Error getting next receipt number: $e');
      rethrow;
    }
  }


// Desktop Layout
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Container(
          width: 400,
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: Colors.grey.shade300,
                width: 1,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCustomerSection(),
              _buildProductInput(),
              if (selectedProduct != null) _buildSelectedProductInfo(),
              const Spacer(),
              _buildCheckoutButton(),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Warenkorb',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(child: _buildCartList()),
              _buildTotalBar(),
            ],
          ),
        ),
      ],
    );
  }
  void _showEditCustomerDialog(Customer customer) {
    final formKey = GlobalKey<FormState>();
    final companyController = TextEditingController(text: customer.company);
    final firstNameController = TextEditingController(text: customer.firstName);
    final lastNameController = TextEditingController(text: customer.lastName);
    final streetController = TextEditingController(text: customer.street);
    final houseNumberController = TextEditingController(text: customer.houseNumber);
    final zipCodeController = TextEditingController(text: customer.zipCode);
    final cityController = TextEditingController(text: customer.city);
    final countryController = TextEditingController(text: customer.country);
    final emailController = TextEditingController(text: customer.email);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Kunde',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unternehmensdaten',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: companyController,
                            decoration: const InputDecoration(
                              labelText: 'Firma *',
                              border: OutlineInputBorder(),
                              filled: true,
                            ),
                            validator: (value) =>
                            value?.isEmpty == true ? 'Bitte Firma eingeben' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kontaktperson',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: firstNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Vorname *',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                  ),
                                  validator: (value) =>
                                  value?.isEmpty == true ? 'Bitte Vorname eingeben' : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: lastNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Nachname *',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                  ),
                                  validator: (value) =>
                                  value?.isEmpty == true ? 'Bitte Nachname eingeben' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: emailController,
                            decoration: const InputDecoration(
                              labelText: 'E-Mail *',
                              border: OutlineInputBorder(),
                              filled: true,
                            ),
                            validator: (value) {
                              if (value?.isEmpty == true) {
                                return 'Bitte E-Mail eingeben';
                              }
                              if (!value!.contains('@')) {
                                return 'Bitte gültige E-Mail eingeben';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Adresse',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: streetController,
                                  decoration: const InputDecoration(
                                    labelText: 'Straße *',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                  ),
                                  validator: (value) =>
                                  value?.isEmpty == true ? 'Bitte Straße eingeben' : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: houseNumberController,
                                  decoration: const InputDecoration(
                                    labelText: 'Nr. *',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                  ),
                                  validator: (value) =>
                                  value?.isEmpty == true ? 'Bitte Nr. eingeben' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: zipCodeController,
                                  decoration: const InputDecoration(
                                    labelText: 'PLZ *',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                  ),
                                  validator: (value) =>
                                  value?.isEmpty == true ? 'Bitte PLZ eingeben' : null,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(5),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: cityController,
                                  decoration: const InputDecoration(
                                    labelText: 'Ort *',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                  ),
                                  validator: (value) =>
                                  value?.isEmpty == true ? 'Bitte Ort eingeben' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: countryController,
                            decoration: const InputDecoration(
                              labelText: 'Land *',
                              border: OutlineInputBorder(),
                              filled: true,
                            ),
                            validator: (value) =>
                            value?.isEmpty == true ? 'Bitte Land eingeben' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Abbrechen'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            if (formKey.currentState?.validate() == true) {
                              try {
                                final updatedCustomer = Customer(
                                  id: customer.id, // Behalte die original ID
                                  company: companyController.text.trim(),
                                  name: companyController.text.trim(),
                                  firstName: firstNameController.text.trim(),
                                  lastName: lastNameController.text.trim(),
                                  street: streetController.text.trim(),
                                  houseNumber: houseNumberController.text.trim(),
                                  zipCode: zipCodeController.text.trim(),
                                  city: cityController.text.trim(),
                                  country: countryController.text.trim(),
                                  email: emailController.text.trim(),
                                );

                                // Update den Kunden in der Datenbank
                                await FirebaseFirestore.instance
                                    .collection('customers')
                                    .doc(customer.id)
                                    .update(updatedCustomer.toMap());

                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Kunde wurde aktualisiert'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Fehler beim Aktualisieren: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('Speichern'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildCustomerListTile(Customer customer, bool isSelected) {
    return Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Text(
            customer.company.substring(0, 1).toUpperCase(),
            style: TextStyle(
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        title: Text(
          customer.company,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : null,

            fontSize: 14,),
          overflow: TextOverflow.ellipsis,
          maxLines:1,
        ),
        // subtitle: Text(
        //   '${customer.fullName}\n${customer.city}' ),
        subtitle: Text(
            '${customer.city}' ),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _showEditCustomerDialog(customer),
        ),
        isThreeLine: false,
        onTap: () => _onCustomerSelected(customer),
      ),
    );
  }
// Mobile Layout
Widget _buildMobileLayout() {
return Column(
children: [
_buildMobileActions(),
Expanded(
child: _buildCartList(),
),
_buildTotalBar(),
],
);
}

// Produkteingabe Widget
Widget _buildProductInput() {
return Padding(
padding: const EdgeInsets.all(16.0),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'Produkt hinzufügen',
style: TextStyle(
fontSize: 20,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 24),
TextFormField(
controller: barcodeController,
decoration: const InputDecoration(
labelText: 'Barcode',
border: OutlineInputBorder(),
helperText: 'Gib den Barcode des Produkts ein',
),
keyboardType: TextInputType.number,
inputFormatters: [FilteringTextInputFormatter.digitsOnly],
onFieldSubmitted: (value) {
if (value.isNotEmpty) {
_fetchProductAndShowQuantityDialog(value);
}
},
),
const SizedBox(height: 16),
ElevatedButton.icon(
onPressed: () {
if (barcodeController.text.isNotEmpty) {
_fetchProductAndShowQuantityDialog(barcodeController.text);
}
},
icon: const Icon(Icons.search),
label: const Text('Produkt suchen'),
style: ElevatedButton.styleFrom(
minimumSize: const Size(double.infinity, 48),
),
),
],
),
);
}
  // Verbesserte Kundenanzeige Widget
  Widget _buildCustomerSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selectedCustomer != null
              ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
              : Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person,
                color: selectedCustomer != null
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 8),
              Text(
                'Kunde',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: selectedCustomer != null
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showCustomerSelection,
                icon: Icon(selectedCustomer != null ? Icons.edit : Icons.add),
                label: Text(selectedCustomer != null ? 'Ändern' : 'Auswählen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedCustomer != null
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.primary,
                  foregroundColor: selectedCustomer != null
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ],
          ),
          if (selectedCustomer != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedCustomer!.company,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(selectedCustomer!.fullName),
                  const SizedBox(height: 2),
                  Text(
                    selectedCustomer!.fullAddress,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selectedCustomer!.email,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text(
                  'Kein Kunde ausgewählt',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onCustomerSelected(Customer customer) async {
    await _saveTemporaryCustomer(customer);
    if (mounted) {
      Navigator.pop(context);
    }
  }

// Verbessertes Kundenauswahlformular
  void _showCustomerSelection() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              body: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Kunde',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: customerSearchController,
                    decoration: InputDecoration(
                      labelText: 'Suchen',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('customers')
                          .orderBy('company')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Center(
                            child: Text('Ein Fehler ist aufgetreten'),
                          );
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final customers = snapshot.data?.docs ?? [];
                        final searchTerm = customerSearchController.text.toLowerCase();

                        final filteredCustomers = customers.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return data['company'].toString().toLowerCase().contains(searchTerm) ||
                              data['firstName'].toString().toLowerCase().contains(searchTerm) ||
                              data['lastName'].toString().toLowerCase().contains(searchTerm);
                        }).toList();

                        if (filteredCustomers.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 48,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Keine Kunden gefunden',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return StreamBuilder<Customer?>(
                          stream: _temporaryCustomerStream,
                          builder: (context, selectedSnapshot) {
                            final selectedCustomer = selectedSnapshot.data;

                            return ListView.builder(
                              itemCount: filteredCustomers.length,
                              itemBuilder: (context, index) {
                                final doc = filteredCustomers[index];
                                final customer = Customer.fromMap(
                                  doc.data() as Map<String, dynamic>,
                                  doc.id,
                                );

                                final isSelected = selectedCustomer?.id == customer.id;

                                return _buildCustomerListTile(customer, isSelected);
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [

                        ElevatedButton.icon(
                          onPressed: _showNewCustomerDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Neuer Kunde'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

// Verbessertes Formular für neue Kunden
  void _showNewCustomerDialog() {
    final formKey = GlobalKey<FormState>();

    final companyController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final streetController = TextEditingController();
    final houseNumberController = TextEditingController();
    final zipCodeController = TextEditingController();
    final cityController = TextEditingController();
    final countryController = TextEditingController(text: 'Schweiz');  // Default
    final emailController = TextEditingController();

    showDialog(
        context: context,
        builder: (context) => Dialog(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                        key: formKey,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Row(
                          children: [
                          Text(
                          'Neuer Kunde',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Unternehmensdaten',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: companyController,
                                decoration: const InputDecoration(
                                  labelText: 'Firma *',
                                  border: OutlineInputBorder(),
                                  filled: true,
                                ),
                                validator: (value) =>
                                value?.isEmpty == true ? 'Bitte Firma eingeben' : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kontaktperson',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: firstNameController,
                                      decoration: const InputDecoration(
                                        labelText: 'Vorname *',
                                        border: OutlineInputBorder(),
                                        filled: true,
                                      ),
                                      validator: (value) =>
                                      value?.isEmpty == true ? 'Bitte Vorname eingeben' : null,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: lastNameController,
                                      decoration: const InputDecoration(
                                        labelText: 'Nachname *',
                                        border: OutlineInputBorder(),
                                        filled: true,
                                      ),
                                      validator: (value) =>
                                      value?.isEmpty == true ? 'Bitte Nachname eingeben' : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: emailController,
                                decoration: const InputDecoration(
                                  labelText: 'E-Mail *',
                                  border: OutlineInputBorder(),
                                  filled: true,
                                ),
                                validator: (value) {
                                  if (value?.isEmpty == true) {
                                    return 'Bitte E-Mail eingeben';
                                  }
                                  if (!value!.contains('@')) {
                                    return 'Bitte gültige E-Mail eingeben';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                              Text(
                              'Adresse',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                              Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: streetController,
                                decoration: const InputDecoration(
                                  labelText: 'Straße *',
                                  border: OutlineInputBorder(),
                                  filled: true,
                                ),
                                validator: (value) =>
                                value?.isEmpty == true ? 'Bitte Straße eingeben' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                                child: TextFormField(
                                    controller: houseNumberController,
                                  decoration: const InputDecoration(
                                    labelText: 'Nr. *',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                  ),
                                  validator: (value) =>
                                  value?.isEmpty == true ? 'Bitte Nr. eingeben' : null,
                                ),
                            ),
                              ],
                            ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: zipCodeController,
                                        decoration: const InputDecoration(
                                          labelText: 'PLZ *',
                                          border: OutlineInputBorder(),
                                          filled: true,
                                        ),
                                        validator: (value) =>
                                        value?.isEmpty == true ? 'Bitte PLZ eingeben' : null,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          LengthLimitingTextInputFormatter(5),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 3,
                                      child: TextFormField(
                                        controller: cityController,
                                        decoration: const InputDecoration(
                                          labelText: 'Ort *',
                                          border: OutlineInputBorder(),
                                          filled: true,
                                        ),
                                        validator: (value) =>
                                        value?.isEmpty == true ? 'Bitte Ort eingeben' : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: countryController,
                                  decoration: const InputDecoration(
                                    labelText: 'Land *',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                  ),
                                  validator: (value) =>
                                  value?.isEmpty == true ? 'Bitte Land eingeben' : null,
                                ),
                              ],
                            ),
                        ),
                              const SizedBox(height: 24),
                              Column(
                                children: [
                                  Text(
                                    '* Pflichtfelder',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.outline,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Row(
                                    children: [

                                      const Spacer(),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                        child: const Text('Abbrechen'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          if (formKey.currentState?.validate() == true) {
                                            try {
                                              final newCustomer = Customer(
                                                id: '',
                                                name: companyController.text.trim(),
                                                company: companyController.text.trim(),
                                                firstName: firstNameController.text.trim(),
                                                lastName: lastNameController.text.trim(),
                                                street: streetController.text.trim(),
                                                houseNumber: houseNumberController.text.trim(),
                                                zipCode: zipCodeController.text.trim(),
                                                city: cityController.text.trim(),
                                                country: countryController.text.trim(),
                                                email: emailController.text.trim(),
                                              );

                                              final docRef = await FirebaseFirestore.instance
                                                  .collection('customers')
                                                  .add(newCustomer.toMap());

                                              setState(() {
                                                selectedCustomer = Customer.fromMap(
                                                  newCustomer.toMap(),
                                                  docRef.id,
                                                );
                                              });

                                              if (mounted) {
                                                Navigator.pop(context); // Schließe Neukunden-Dialog
                                            //    Navigator.pop(context); // Schließe Kundenauswahl-Dialog
                                                AppToast.show(message: 'Kunde wurde erfolgreich angelegt', height: h);

                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                AppToast.show(message: 'Fehler beim Anlegen: $e', height: h);

                                              }
                                            }
                                          }
                                        },
                                        icon: const Icon(Icons.save),
                                        label: const Text('Speichern'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ),
                ),
            ),
        ),
    );
  }



  // Stream für den temporären Kunden
  Stream<Customer?> get _temporaryCustomerStream => FirebaseFirestore.instance
      .collection('temporary_customer')
      .limit(1)
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isEmpty) return null;
    return Customer.fromMap(
      snapshot.docs.first.data(),
      snapshot.docs.first.id,
    );
  });

  // Methode zum Speichern des temporären Kunden
  Future<void> _saveTemporaryCustomer(Customer customer) async {
    try {
      // Lösche vorherige temporäre Kunden
      final tempDocs = await FirebaseFirestore.instance
          .collection('temporary_customer')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in tempDocs.docs) {
        batch.delete(doc.reference);
      }

      // Füge neuen temporären Kunden hinzu
      batch.set(
        FirebaseFirestore.instance.collection('temporary_customer').doc(customer.id),
        {
          ...customer.toMap(),
          'timestamp': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();
    } catch (e) {
      print('Fehler beim Speichern des temporären Kunden: $e');
    }
  }


// Mobile Aktionsbuttons
  Widget _buildMobileActions() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // Neuer Suchen-Button
          Expanded(
            child: ElevatedButton(
              onPressed: _showWarehouseDialog,
              child:const Icon(Icons.search),


            ),
          ),
          const SizedBox(width: 8),
          // Bestehender Scan-Button
          Expanded(
            child: ElevatedButton(
              onPressed: _scanProduct,
             child: const Icon(Icons.qr_code_scanner),

            ),
          ),
          const SizedBox(width: 8),
          // Bestehender Eingabe-Button
          Expanded(
            child: ElevatedButton(
              onPressed: _showBarcodeInputDialog,
             child: const Icon(Icons.keyboard),

            ),
          ),
        ],
      ),
    );
  }


// Erweiterte Warenkorb-Anzeige
  Widget _buildCartList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _basketStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Ein Fehler ist aufgetreten'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final basketItems = snapshot.data?.docs ?? [];

        if (basketItems.isEmpty) {
          return const Center(child: Text('Keine Produkte im Warenkorb'));
        }

        return ListView.builder(
          itemCount: basketItems.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            final doc = basketItems[index];
            final item = doc.data() as Map<String, dynamic>;
            final itemId = doc.id;
            final quantity = item['quantity'] as int;
            final pricePerUnit = item['price_per_unit'] as double;
            final subtotal = quantity * pricePerUnit;
            final itemDiscount = _itemDiscounts[itemId] ?? const Discount();
            final discountAmount = itemDiscount.calculateDiscount(subtotal);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  ListTile(
                    title: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['product_name'] ?? 'N/A',
                                style: const TextStyle(fontWeight: FontWeight.bold,   fontSize: 12,),
                              ),
                              Text(
                                '${quantity} ${item['unit']} × ${pricePerUnit.toStringAsFixed(2)} CHF',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${subtotal.toStringAsFixed(2)} CHF',
                              style: TextStyle(
                                fontSize: 11,
                                decoration: discountAmount > 0 ?
                                TextDecoration.lineThrough : null,
                                color: discountAmount > 0 ?
                                Colors.grey : null,
                              ),
                            ),
                            if (discountAmount > 0)
                              Text(
                                '${(subtotal - discountAmount).toStringAsFixed(2)} CHF',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.discount,
                            color: itemDiscount.hasDiscount ?
                            Theme.of(context).colorScheme.primary : null,
                          ),
                          onPressed: () => _showItemDiscountDialog(itemId, subtotal),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _removeFromBasket(doc.id),
                        ),
                      ],
                    ),
                  ),
                  if (itemDiscount.hasDiscount)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Rabatt: ${itemDiscount.percentage > 0 ? '${itemDiscount.percentage}% ' : ''}'
                                '${itemDiscount.absolute > 0 ? '${itemDiscount.absolute} CHF' : ''}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Text(
                            '- ${discountAmount.toStringAsFixed(2)} CHF',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
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
    );
  }

// Erweiterte Gesamtsummen-Anzeige
  Widget _buildTotalBar() {
    return StreamBuilder<QuerySnapshot>(
      stream: _basketStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final basketItems = snapshot.data!.docs;

        // Berechne Zwischensummen
        double subtotal = 0.0;
        double itemDiscounts = 0.0;

        for (var doc in basketItems) {
          final data = doc.data() as Map<String, dynamic>;
          final itemSubtotal = (data['quantity'] as int) *
              (data['price_per_unit'] as double);
          subtotal += itemSubtotal;

          final itemDiscount = _itemDiscounts[doc.id] ?? const Discount();
          itemDiscounts += itemDiscount.calculateDiscount(itemSubtotal);
        }

        final afterItemDiscounts = subtotal - itemDiscounts;
        final totalDiscountAmount = _totalDiscount.calculateDiscount(afterItemDiscounts);
        final netAmount = afterItemDiscounts - totalDiscountAmount;
        final vatAmount = netAmount * (_vatRate / 100);
        final total = netAmount + vatAmount;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Zwischensumme
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Zwischensumme'),
                    Text('${subtotal.toStringAsFixed(2)} CHF'),
                  ],
                ),

                // Positionsrabatte
                if (itemDiscounts > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Positionsrabatte'),
                      Text(
                        '- ${itemDiscounts.toStringAsFixed(2)} CHF',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],

                // Gesamtrabatt
                if (_totalDiscount.hasDiscount) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          'Gesamtrabatt '
                              '${_totalDiscount.percentage > 0 ? '(${_totalDiscount.percentage}%)' : ''}'
                              '${_totalDiscount.absolute > 0 ? ' ${_totalDiscount.absolute} CHF' : ''}'
                      ),
                      Text(
                        '- ${totalDiscountAmount.toStringAsFixed(2)} CHF',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],

                // Nettobetrag
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Nettobetrag'),
                    Text('${netAmount.toStringAsFixed(2)} CHF'),
                  ],
                ),

                // MwSt
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('MwSt ($_vatRate%)'),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 16),
                          onPressed: _showVatRateDialog,
                        ),
                        Text('${vatAmount.toStringAsFixed(2)} CHF'),
                      ],
                    ),
                  ],
                ),

                const Divider(height: 16),

                // Gesamtbetrag
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Gesamtbetrag',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${total.toStringAsFixed(2)} CHF',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Aktionsbuttons
                Row(
                  children: [
                    // Rabatt-Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: basketItems.isEmpty ? null : _showTotalDiscountDialog,
                        icon: Icon(
                          Icons.discount,
                          color: _totalDiscount.hasDiscount ?
                          Theme.of(context).colorScheme.primary : null,
                        ),
                        label: const Text('Gesamtrabatt'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Abschließen-Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: basketItems.isEmpty || isLoading
                            ? null
                            : _processTransaction,
                        icon: isLoading
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Icon(Icons.check),
                        label: const Text('Abschließen'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
// Hilfsmethoden
  Future<int> _getAvailableQuantity(String shortBarcode) async {
    try {
      // Aktuellen Bestand aus inventory collection abrufen
      final inventoryDoc = await FirebaseFirestore.instance
          .collection('inventory')
          .doc(shortBarcode)
          .get();

      final currentStock = (inventoryDoc.data()?['quantity'] ?? 0) as int;

      // Temporär gebuchte Menge abrufen
      final tempBasketDoc = await FirebaseFirestore.instance
          .collection('temporary_basket')
          .where('product_id', isEqualTo: shortBarcode)
          .get();

      final reservedQuantity = tempBasketDoc.docs.fold<int>(
        0,
            (sum, doc) => sum + (doc.data()['quantity'] as int),
      );

      return currentStock - reservedQuantity;
    } catch (e) {
      print('Fehler beim Abrufen der verfügbaren Menge: $e');
      return 0;
    }
  }


  Future<void> _addToTemporaryBasket(String shortBarcode, Map<String, dynamic> productData, int quantity) async {
    await FirebaseFirestore.instance
        .collection('temporary_basket')
        .add({
      'product_id': shortBarcode,
      'product_name': productData['product_name'],
      'quantity': quantity,
      'timestamp': FieldValue.serverTimestamp(),
      'price_per_unit': productData['price_CHF'],
      'unit': productData['unit'],
      'instrument_name': productData['instrument_name'],
      'instrument_code': productData['instrument_code'],
      'part_name': productData['part_name'],
      'part_code': productData['part_code'],
      'wood_name': productData['wood_name'],
      'wood_code': productData['wood_code'],
      'quality_name': productData['quality_name'],
      'quality_code': productData['quality_code'],
    });
  }

Future<void> _removeFromBasket(String basketItemId) async {
await FirebaseFirestore.instance
    .collection('temporary_basket')
    .doc(basketItemId)
    .delete();
}

void _showQuantityDialog(String barcode, Map<String, dynamic> productData) {
quantityController.clear();
showDialog(
context: context,
builder: (BuildContext context) {
return AlertDialog(
title: const Text('Menge eingeben'),
content: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('Produkt: ${productData['product_name'] ?? 'N/A'}'),
FutureBuilder<int>(
future: _getAvailableQuantity(barcode),
builder: (context, snapshot) {
if (snapshot.hasData) {
return Text(
'Verfügbar: ${snapshot.data} ${productData['unit'] ?? 'Stück'}',
);
}
return const CircularProgressIndicator();
},
),
const SizedBox(height: 16),
TextFormField(
controller: quantityController,
decoration: const InputDecoration(
labelText: 'Menge',
border: OutlineInputBorder(),
),
keyboardType: TextInputType.number,
inputFormatters: [FilteringTextInputFormatter.digitsOnly],
autofocus: true,
),
],
),
actions: [
TextButton(
onPressed: () => Navigator.pop(context),
child: const Text('Abbrechen'),
),
ElevatedButton(
onPressed: () async {
if (quantityController.text.isNotEmpty) {
final quantity = int.parse(quantityController.text);
final availableQuantity = await _getAvailableQuantity(barcode);

if (quantity <= availableQuantity) {
await _addToTemporaryBasket(barcode, productData, quantity);
Navigator.pop(context);
} else {
  AppToast.show(message: "Nicht genügend Bestand verfügbar", height: h);

}
}
},
child: const Text('Hinzufügen'),
),
],
);
},
);
}

  Future<void> _fetchProductAndShowQuantityDialog(String barcode) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('inventory')  // Geändert von 'products' zu 'inventory'
          .doc(barcode)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        final productData = doc.data() as Map<String, dynamic>;
        _showQuantityDialog(barcode, productData);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produkt nicht gefunden'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Laden: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
    void _showBarcodeInputDialog() {
barcodeController.clear();
showDialog(
context: context,
builder: (BuildContext context) {
return AlertDialog(
title: const Text('Barcode eingeben'),
content: TextFormField(
controller: barcodeController,
decoration: const InputDecoration(
labelText: 'Barcode',
border: OutlineInputBorder(),
),
keyboardType: TextInputType.number,
//inputFormatters: [FilteringTextInputFormatter.digitsOnly],
autofocus: true,
),
actions: [
TextButton(
onPressed: () => Navigator.pop(context),
child: const Text('Abbrechen'),
),
ElevatedButton(
onPressed: () {
if (barcodeController.text.isNotEmpty) {
Navigator.pop(context);
_fetchProductAndShowQuantityDialog(barcodeController.text);
}
},
child: const Text('Suchen'),
),
],
);
},
);
}

    Future<void> _scanProduct() async {
try {
String barcodeResult = await FlutterBarcodeScanner.scanBarcode(
'#ff6666',
'Abbrechen',
true,
ScanMode.BARCODE,
);

if (barcodeResult != '-1') {
await _fetchProductAndShowQuantityDialog(barcodeResult);
}
} on PlatformException {
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Fehler beim Scannen'),
backgroundColor: Colors.red,
),
);
}
}

  // Korrigierte _processTransaction Methode
  Future<void> _processTransaction() async {
    setState(() => isLoading = true);

    try {

      // Prüfe ob Kostenstelle ausgewählt wurde
      final costCenterSnapshot = await FirebaseFirestore.instance
          .collection('temporary_cost_center')
          .limit(1)
          .get();

      if (costCenterSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bitte wähle eine Kostenstelle aus'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Hole die nächste Lieferscheinnummer
      final receiptNumber = await _getNextReceiptNumber();

      // Erstelle eine neue Referenz mit der Nummer als ID
      final receiptRef = FirebaseFirestore.instance
          .collection('sales_receipts')
          .doc('LS-$receiptNumber');

      // 1. Prüfe Kundenauswahl
      final customerSnapshot = await FirebaseFirestore.instance
          .collection('temporary_customer')
          .limit(1)
          .get();

      if (customerSnapshot.docs.isEmpty) {
        setState(() => isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bitte wähle einen Kunden aus'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final customerData = customerSnapshot.docs.first.data();
      final customer = Customer.fromMap(customerData, customerSnapshot.docs.first.id);

      // 2. Hole die aktuelle Messe
      final fairSnapshot = await FirebaseFirestore.instance
          .collection('temporary_fair')
          .limit(1)
          .get();

      final fair = fairSnapshot.docs.isEmpty
          ? null
          : Fair.fromMap(
        fairSnapshot.docs.first.data(),
        fairSnapshot.docs.first.id,
      );

      // 3. Prüfe Warenkorb
      final basketSnapshot = await FirebaseFirestore.instance
          .collection('temporary_basket')
          .get();

      if (basketSnapshot.docs.isEmpty) {
        setState(() => isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Der Warenkorb ist leer'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 4. Prüfe Verfügbarkeit
      for (final item in basketSnapshot.docs) {
        final itemData = item.data();
        final availableQuantity = await _getAvailableQuantity(itemData['product_id']);

        if (availableQuantity<0) {
          print("test");
          setState(() => isLoading = false);
          if (mounted) {
            AppToast.show(message:  'Nicht genügend Bestand für ${itemData['product_name']}. '
                'Verfügbar: $availableQuantity ${itemData['unit']}', height: h);

          }
          return;
        }
      }

      // 5. Berechne alle Summen
      double subtotal = 0.0;
      double itemDiscounts = 0.0;
      final items = basketSnapshot.docs.map((doc) {
        final data = doc.data();
        final itemSubtotal = (data['quantity'] as int) *
            (data['price_per_unit'] as double);
        subtotal += itemSubtotal;

        final itemDiscount = _itemDiscounts[doc.id] ?? const Discount();
        final discountAmount = itemDiscount.calculateDiscount(itemSubtotal);
        itemDiscounts += discountAmount;

        return {
          ...data,
          'subtotal': itemSubtotal,
          'discount': itemDiscount.toMap(),
          'discount_amount': discountAmount,
          'total': itemSubtotal - discountAmount,
        };
      }).toList();

      final afterItemDiscounts = subtotal - itemDiscounts;
      final totalDiscountAmount = _totalDiscount.calculateDiscount(afterItemDiscounts);
      final netAmount = afterItemDiscounts - totalDiscountAmount;
      final vatAmount = netAmount * (_vatRate / 100);
      final total = netAmount + vatAmount;

      // 6. Erstelle Verkaufsbeleg
      final batch = FirebaseFirestore.instance.batch();
     // final receiptRef = FirebaseFirestore.instance.collection('sales_receipts').doc();

      // 7. Speichere Verkaufsbeleg
      batch.set(receiptRef, {
        'receiptNumber': receiptNumber,
        'customer': {
          'id': customer.id,
          'company': customer.company,
          'firstName': customer.firstName,
          'lastName': customer.lastName,
          'fullName': customer.fullName,
          'street': customer.street,
          'houseNumber': customer.houseNumber,
          'zipCode': customer.zipCode,
          'city': customer.city,
          'country': customer.country,
          'email': customer.email,
        },
        'fair': fair == null ? null : {
          'id': fair.id,
          'name': fair.name,
          'location': fair.location,
          'city': fair.city,
          'country': fair.country,
          'costCenterCode': fair.costCenterCode,
          'startDate': fair.startDate.toIso8601String(),
          'endDate': fair.endDate.toIso8601String(),
        },
        'items': items,
        'calculations': {
          'subtotal': subtotal,
          'item_discounts': itemDiscounts,
          'total_discount': _totalDiscount.toMap(),
          'total_discount_amount': totalDiscountAmount,
          'net_amount': netAmount,
          'vat_rate': _vatRate,
          'vat_amount': vatAmount,
          'total': total,
        },
        'metadata': {
          'fairId': fair?.id,
          'fairName': fair?.name,
          'fairCostCenter': fair?.costCenterCode,
          'timestamp': FieldValue.serverTimestamp(),
          'has_discounts': itemDiscounts > 0 || totalDiscountAmount > 0,
        }
      });

      // 8. Aktualisiere Lagerbestand
      for (final doc in basketSnapshot.docs) {
        final data = doc.data();
        final inventoryRef = FirebaseFirestore.instance
            .collection('inventory')
            .doc(data['product_id']);

        // Reduziere Bestand
        batch.update(inventoryRef, {
          'quantity': FieldValue.increment(-(data['quantity'] as int)),
          'last_modified': FieldValue.serverTimestamp(),
        });

        // Erstelle Stock Entry
        final stockEntryRef = FirebaseFirestore.instance
            .collection('stock_entries')
            .doc();

        batch.set(stockEntryRef, {
          'product_id': data['product_id'],
          'product_name': data['product_name'],
          'quantity_change': -(data['quantity'] as int),
          'type': 'sale',
          'sale_receipt_id': receiptRef.id,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Lösche Warenkorb-Eintrag
        batch.delete(doc.reference);
      }

      // 9. Lösche temporäre Daten
      batch.delete(customerSnapshot.docs.first.reference);
      if (fair != null) {
        batch.delete(fairSnapshot.docs.first.reference);
      }

      // 10. Führe alle Änderungen durch
      await batch.commit();

      // 11. Generiere und speichere PDF
      final pdfBytes = await _generateEnhancedPdf(receiptRef.id);
      final storage = FirebaseStorage.instance;
      final pdfRef = storage.ref().child('receipts/${receiptRef.id}.pdf');
      await pdfRef.putData(pdfBytes);
      final pdfUrl = await pdfRef.getDownloadURL();

      // 12. Aktualisiere Beleg mit PDF-URL
      await receiptRef.update({'pdf_url': pdfUrl});

      // 13. Generiere CSV wenn nötig
      Uint8List? csvBytes;

        csvBytes = await _generateCsv(receiptRef.id);
        final csvRef = storage.ref().child('receipts/${receiptRef.id}.csv');
        await csvRef.putData(csvBytes);
        final csvUrl = await csvRef.getDownloadURL();
        await receiptRef.update({'csv_url': csvUrl});



      if (mounted) {
        // Stelle sicher, dass csvBytes nicht null ist, wenn es verwendet wird
        final Uint8List? finalCsvBytes = csvBytes != null ? csvBytes : null;

        await _sendConfiguredEmails(
          receiptRef.id,
          pdfBytes,
          finalCsvBytes,
          (await receiptRef.get()).data()!,
        );
      }
      setState(() => isLoading = false);

      // 14. Zeige Erfolgsbestätigung
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Verkauf erfolgreich'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Der Verkauf wurde erfolgreich abgeschlossen.'),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _shareReceipt(
                          receiptRef.id,
                          pdfBytes,
                        ),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('PDF teilen'),
                      ),
                    ),
                  ],
                ),
                if ( csvBytes != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _shareCsv(
                            receiptRef.id,
                            csvBytes,
                          ),
                          icon: const Icon(Icons.table_chart),
                          label: const Text('CSV teilen'),
                        ),
                      ),
                    ],
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
    } catch (e) {
      print('Error in _processTransaction: $e');
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Verarbeiten: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }


    }
  }


  DateTime getDateTimeFromTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    if (timestamp is String) return DateTime.parse(timestamp);
    return DateTime.now();
  }

// CSV-Generierung
  Future<Uint8List> _generateCsv(String receiptId) async {
    final receiptDoc = await FirebaseFirestore.instance
        .collection('sales_receipts')
        .doc(receiptId)
        .get();

    final data = receiptDoc.data()!;
    final receiptNumber = data['receiptNumber'] as String;
    final items = data['items'] as List<dynamic>;
    final calculations = data['calculations'] as Map<String, dynamic>;
    final timestamp = getDateTimeFromTimestamp(data['metadata']['timestamp']);

    // Kopfzeile mit Beleg-Info
    final List<List<dynamic>> csvData = [
      [
        'Lieferschein Nr.:', 'LS-$receiptNumber',
        'Datum:', DateFormat('dd.MM.yyyy').format(timestamp),
      ],
      [], // Leerzeile
      [
        // Header für Artikel
        'Artikelnummer',
        'Artikelbezeichnung',
        'Qualität',
        'Menge',
        'Einheit',
        'Einzelpreis',
        'Positionsrabatt %',
        'Positionsrabatt CHF',
        'Positionssumme',
        'Zwischensumme',
        'Positionsrabatte',
        'Gesamtrabatt %',
        'Gesamtrabatt CHF',
        'Nettobetrag',
        'MwSt %',
        'MwSt CHF',
        'Gesamtbetrag'
      ]
    ];

    // Artikel-Daten
    for (final item in items) {
      csvData.add([
        item['product_id'] ?? '',
        item['product_name'] ?? '',
        item['quality_name'] ?? '',
        item['quantity'] ?? 0,
        item['unit'] ?? '',
        item['price_per_unit'] ?? 0,
        (item['discount'] as Map<String, dynamic>?)?['percentage'] ?? 0,
        item['discount_amount'] ?? 0,
        item['total'] ?? 0,
        // Summen nur in der ersten Zeile
        if (items.indexOf(item) == 0) ...[
          calculations['subtotal'] ?? 0,
          calculations['item_discounts'] ?? 0,
          (calculations['total_discount'] as Map<String, dynamic>?)?['percentage'] ?? 0,
          calculations['total_discount_amount'] ?? 0,
          calculations['net_amount'] ?? 0,
          calculations['vat_rate'] ?? 0,
          calculations['vat_amount'] ?? 0,
          calculations['total'] ?? 0,
        ] else ...[
          '', '', '', '', '', '', '', '', // Leere Zellen für die Summen
        ],
      ]);
    }

    // Formatierung als CSV mit deutschem Excel-Format
    final csvString = const ListToCsvConverter().convert(
      csvData,
      fieldDelimiter: ';',
      textDelimiter: '"',
      textEndDelimiter: '"',
    );

    // BOM für Excel + CSV Daten
    final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(csvString)];
    return Uint8List.fromList(bytes);
  }


// Optional: Hilfsmethode für die Analyse der Messeverkäufe
  Future<Map<String, dynamic>> analyzeFairSales(String fairId) async {
    final sales = await FirebaseFirestore.instance
        .collection('sales_receipts')
        .where('metadata.fairId', isEqualTo: fairId)
        .get();

    double totalRevenue = 0;
    double totalVat = 0;
    Map<String, int> productsSold = {};
    Set<String> uniqueCustomers = {};

    for (final sale in sales.docs) {
      final data = sale.data();
      final calculations = data['calculations'] as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>;

      totalRevenue += calculations['total'] as double;
      totalVat += calculations['vat_amount'] as double;
      uniqueCustomers.add(data['customer']['id'] as String);

      for (final item in items) {
        final productId = item['product_id'] as String;
        final quantity = item['quantity'] as int;
        productsSold[productId] = (productsSold[productId] ?? 0) + quantity;
      }
    }

    return {
      'totalRevenue': totalRevenue,
      'totalVat': totalVat,
      'totalSales': sales.docs.length,
      'uniqueCustomers': uniqueCustomers.length,
      'productsSold': productsSold,
    };
  }


  // Future<Uint8List> _generatePdf(String receiptId) async {
  //   final pdf = pw.Document();
  //   final receiptDoc = await FirebaseFirestore.instance
  //       .collection('sales_receipts')
  //       .doc(receiptId)
  //       .get();
  //
  //   final receiptData = receiptDoc.data()!;
  //   final customerData = receiptData['customer'] as Map<String, dynamic>;
  //   final items = (receiptData['items'] as List).cast<Map<String, dynamic>>();
  //
  //   // Lade das Firmenlogo
  //   final logoImage = await rootBundle.load('images/logo.png');
  //   final logo = pw.MemoryImage(logoImage.buffer.asUint8List());
  //
  //   pdf.addPage(
  //     pw.Page(
  //       build: (pw.Context context) {
  //         return pw.Column(
  //           crossAxisAlignment: pw.CrossAxisAlignment.start,
  //           children: [
  //             // Header mit Logo und Firmeninformationen
  //             pw.Row(
  //               mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  //               children: [
  //                 pw.Column(
  //                   crossAxisAlignment: pw.CrossAxisAlignment.start,
  //                   children: [
  //                     pw.Text(
  //                       'Lieferschein',
  //                       style: pw.TextStyle(
  //                         fontSize: 24,
  //                         fontWeight: pw.FontWeight.bold,
  //                       ),
  //                     ),
  //                     pw.SizedBox(height: 4),
  //                     pw.Text(
  //                       'Nummer: $receiptId',
  //                       style: const pw.TextStyle(fontSize: 12),
  //                     ),
  //                     pw.Text(
  //                       'Datum: ${DateFormat('dd.MM.yyyy').format(DateTime.now())}',
  //                       style: const pw.TextStyle(fontSize: 12),
  //                     ),
  //                   ],
  //                 ),
  //                 pw.Image(logo, width: 150),
  //               ],
  //             ),
  //             pw.SizedBox(height: 40),
  //
  //             // Kundenadresse
  //             pw.Container(
  //               padding: const pw.EdgeInsets.all(10),
  //               decoration: pw.BoxDecoration(
  //                 border: pw.Border.all(color: PdfColors.grey300),
  //               ),
  //               child: pw.Column(
  //                 crossAxisAlignment: pw.CrossAxisAlignment.start,
  //                 children: [
  //                   pw.Text(
  //                     customerData['company'],
  //                     style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
  //                   ),
  //                   pw.Text(customerData['fullName']),
  //                   pw.Text(customerData['address']),
  //                 ],
  //               ),
  //             ),
  //             pw.SizedBox(height: 20),
  //
  //             // Artikel-Tabelle
  //             pw.Table(
  //               border: pw.TableBorder.all(color: PdfColors.grey300),
  //               columnWidths: {
  //                 0: const pw.FlexColumnWidth(4), // Produkt
  //                 1: const pw.FlexColumnWidth(1), // Menge
  //                 2: const pw.FlexColumnWidth(1), // Einheit
  //                 3: const pw.FlexColumnWidth(2), // Preis/Einheit
  //                 4: const pw.FlexColumnWidth(2), // Gesamt
  //               },
  //               children: [
  //                 // Header
  //                 pw.TableRow(
  //                   decoration: pw.BoxDecoration(
  //                     color: PdfColors.grey200,
  //                   ),
  //                   children: [
  //                     pw.Padding(
  //                       padding: const pw.EdgeInsets.all(5),
  //                       child: pw.Text(
  //                         'Produkt',
  //                         style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
  //                       ),
  //                     ),
  //                     pw.Padding(
  //                       padding: const pw.EdgeInsets.all(5),
  //                       child: pw.Text(
  //                         'Menge',
  //                         style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
  //                       ),
  //                     ),
  //                     pw.Padding(
  //                       padding: const pw.EdgeInsets.all(5),
  //                       child: pw.Text(
  //                         'Einheit',
  //                         style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
  //                       ),
  //                     ),
  //                     pw.Padding(
  //                       padding: const pw.EdgeInsets.all(5),
  //                       child: pw.Text(
  //                         'Preis/Einheit',
  //                         style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
  //                         textAlign: pw.TextAlign.right,
  //                       ),
  //                     ),
  //                     pw.Padding(
  //                       padding: const pw.EdgeInsets.all(5),
  //                       child: pw.Text(
  //                         'Gesamt',
  //                         style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
  //                         textAlign: pw.TextAlign.right,
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //                 // Artikel
  //                 ...items.map((item) => pw.TableRow(
  //                   children: [
  //                     pw.Padding(
  //                       padding: const pw.EdgeInsets.all(5),
  //                       child: pw.Column(
  //                         crossAxisAlignment: pw.CrossAxisAlignment.start,
  //                         children: [
  //                           pw.Text(item['product_name']),
  //                           pw.SizedBox(height: 2),
  //                           pw.Text(
  //                             '${item['instrument_name']} - ${item['part_name']} - ${item['wood_name']} - ${item['quality_name']}',
  //                             style: const pw.TextStyle(
  //                               fontSize: 10,
  //                               color: PdfColors.grey700,
  //                             ),
  //                           ),
  //                         ],
  //                       ),
  //                     ),
  //                     pw.Padding(
  //                       padding: const pw.EdgeInsets.all(5),
  //                       child: pw.Text(item['quantity'].toString()),
  //                     ),
  //                     pw.Padding(
  //                       padding: const pw.EdgeInsets.all(5),
  //                       child: pw.Text(item['unit']),
  //                     ),
  //                     pw.Padding(
  //                       padding: const pw.EdgeInsets.all(5),
  //                       child: pw.Text(
  //                         '${item['price_per_unit'].toStringAsFixed(2)} CHF',
  //                         textAlign: pw.TextAlign.right,
  //                       ),
  //                     ),
  //                     pw.Padding(
  //                       padding: const pw.EdgeInsets.all(5),
  //                       child: pw.Text(
  //                         '${item['total_price'].toStringAsFixed(2)} CHF',
  //                         textAlign: pw.TextAlign.right,
  //                       ),
  //                     ),
  //                   ],
  //                 )),
  //               ],
  //             ),
  //             pw.SizedBox(height: 20),
  //
  //             // Gesamtsumme
  //             pw.Container(
  //               alignment: pw.Alignment.centerRight,
  //               child: pw.Column(
  //                 crossAxisAlignment: pw.CrossAxisAlignment.end,
  //                 children: [
  //                   pw.Text(
  //                     'Gesamtbetrag: ${receiptData['total_amount'].toStringAsFixed(2)} CHF',
  //                     style: pw.TextStyle(
  //                       fontSize: 16,
  //                       fontWeight: pw.FontWeight.bold,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //
  //             // Footer
  //             pw.Positioned(
  //               bottom: 30,
  //               child: pw.Container(
  //                 alignment: pw.Alignment.center,
  //                 width: 500,
  //                 child: pw.Text(
  //                   'Vielen Dank für Ihren Einkauf!',
  //                   style: const pw.TextStyle(
  //                     color: PdfColors.grey700,
  //                     fontSize: 12,
  //                   ),
  //                 ),
  //               ),
  //             ),
  //           ],
  //         );
  //       },
  //     ),
  //   );
  //
  //   return pdf.save();
  // }
// 2. Erweiterte PDF-Generierung
  Future<Uint8List> _generateEnhancedPdf(String receiptId)  async {
    final pdf = pw.Document();
    final receiptDoc = await FirebaseFirestore.instance
        .collection('sales_receipts')
        .doc(receiptId)
        .get();

    final receiptData = receiptDoc.data()!;
    final customerData = receiptData['customer'] as Map<String, dynamic>;
    final items = (receiptData['items'] as List).cast<Map<String, dynamic>>();
    final calculations = receiptData['calculations'] as Map<String, dynamic>;
    final receiptNumber = receiptData['receiptNumber'] as String;

    // Lade das Firmenlogo
    final logoImage = await rootBundle.load('images/logo.png');
    final logo = pw.MemoryImage(logoImage.buffer.asUint8List());

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header-Sektion bleibt gleich...
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Lieferschein',
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey800,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Nr.: LS-$receiptNumber', // Verwende die neue Nummer
                        style: const pw.TextStyle(fontSize: 12, color: PdfColors.blueGrey600),
                      ),
                      pw.Text(
                        'Datum: ${DateFormat('dd.MM.yyyy').format(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 12, color: PdfColors.blueGrey600),
                      ),
                    ],
                  ),
                  pw.Image(logo, width: 180),
                ],
              ),
              pw.SizedBox(height: 20),


              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  color: PdfColors.grey50,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      customerData['company'] ?? '',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey800,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      customerData['fullName'] ?? '',
                      style: const pw.TextStyle(color: PdfColors.blueGrey700),
                    ),
                    pw.SizedBox(height: 4),
                    // Straße und Hausnummer in einer Zeile
                    pw.Text(
                      '${customerData['street'] ?? ''} ${customerData['houseNumber'] ?? ''}',
                      style: const pw.TextStyle(color: PdfColors.blueGrey700),
                    ),
                    // PLZ und Stadt in einer Zeile
                    pw.Text(
                      '${customerData['zipCode'] ?? ''} ${customerData['city'] ?? ''}',
                      style: const pw.TextStyle(color: PdfColors.blueGrey700),
                    ),
                    // Land in einer eigenen Zeile
                    pw.Text(
                      customerData['country'] ?? '',
                      style: const pw.TextStyle(color: PdfColors.blueGrey700),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'per mail an:',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey800,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      customerData['email'] ?? '',
                      style: const pw.TextStyle(color: PdfColors.blueGrey700,  fontSize: 8,),
                    ),
                  ],
                ),
              ),



              pw.SizedBox(height: 15),
              // Erweiterte Artikel-Tabelle mit Rabatten
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(5), // Produkt
                  1: const pw.FlexColumnWidth(2), // Menge
                  2: const pw.FlexColumnWidth(2), // Einheit
                  3: const pw.FlexColumnWidth(3), // Preis/Einheit
                  4: const pw.FlexColumnWidth(2), // Rabatt
                  5: const pw.FlexColumnWidth(3), // Summe
                },
                children: [
                  // Erweiterter Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blueGrey50,
                    ),
                    children: [
                      _buildHeaderCell('Produkt',12),
                      _buildHeaderCell('Menge',9),
                      _buildHeaderCell('Einheit',9),
                      _buildHeaderCell('Preis/Einheit',9, align: pw.TextAlign.right),
                      _buildHeaderCell('Rabatt',9, align: pw.TextAlign.right),
                      _buildHeaderCell('Summe',12, align: pw.TextAlign.right),
                    ],
                  ),
                  // Artikel mit Rabatten
                  ...items.map((item) {
                    final quantity = item['quantity'] as num? ?? 0;
                    final pricePerUnit = item['price_per_unit'] as num? ?? 0;

                    final discount = item['discount'] as Map<String, dynamic>?;
                    final discountAmount = item['discount_amount'] as num? ?? 0;
                    final total = item['total'] as num? ?? 0;

                    return pw.TableRow(
                      children: [
                        _buildContentCell(
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                item['product_name'] ?? '',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                '${'Artikelnummer:'} - ${item['product_id'] ?? ''}',
                                style: const pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.blueGrey600,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                '${'Qualität:'} - ${item['quality_name'] ?? ''}',
                                style: const pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.blueGrey600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildContentCell(pw.Text(quantity.toString(),style: const pw.TextStyle( fontSize: 9,),)),
                        _buildContentCell(pw.Text(item['unit'] ?? '',style: const pw.TextStyle( fontSize: 9,),)),
                        _buildContentCell(
                          pw.Text(
                            '${pricePerUnit.toStringAsFixed(2)} CHF',
                            style: const pw.TextStyle(fontSize: 9,),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        _buildContentCell(
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              if (discount != null && discount['percentage'] > 0)
                                pw.Text(
                                  '${discount['percentage']}%',
                                  style: const pw.TextStyle(color: PdfColors.red,  fontSize: 9,),
                                  textAlign: pw.TextAlign.right,

                                ),
                              if (discount != null && discount['absolute'] > 0)
                                pw.Text(
                                  '${discount['absolute']} CHF',
                                  style: const pw.TextStyle(color: PdfColors.red,  fontSize: 9,),
                                  textAlign: pw.TextAlign.right,

                                ),
                              if (discountAmount > 0)
                                pw.Text(
                                  '-${discountAmount.toStringAsFixed(2)} CHF',
                                  style: const pw.TextStyle(color: PdfColors.red,  fontSize: 9,),
                                  textAlign: pw.TextAlign.right,
                                ),
                            ],
                          ),
                        ),
                        _buildContentCell(
                          pw.Text(
                            style: const pw.TextStyle( fontSize: 9,),
                            '${total.toStringAsFixed(2)} CHF',
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),

              // Erweiterte Gesamtberechnung
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blueGrey50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      _buildTotalRow(
                        'Zwischensumme:',
                        calculations['subtotal'] as num? ?? 0,
                      ),
                      if ((calculations['item_discounts'] as num? ?? 0) > 0)
                        _buildTotalRow(
                          'Positionsrabatte:',
                          calculations['item_discounts'] as num? ?? 0,
                          isDiscount: true,
                        ),
                      if ((calculations['total_discount_amount'] as num? ?? 0) > 0) ...[
                        if ((calculations['total_discount'] as Map<String, dynamic>)['percentage'] > 0)
                          _buildTotalRow(
                            'Gesamtrabatt (${(calculations['total_discount'] as Map<String, dynamic>)['percentage']}%):',
                            calculations['total_discount_amount'] as num? ?? 0,
                            isDiscount: true,
                          ),
                        if ((calculations['total_discount'] as Map<String, dynamic>)['absolute'] > 0)
                          _buildTotalRow(
                            'Gesamtrabatt (absolut):',
                            (calculations['total_discount'] as Map<String, dynamic>)['absolute'] as num? ?? 0,
                            isDiscount: true,
                          ),
                      ],
                      _buildTotalRow(
                        'Nettobetrag:',
                        calculations['net_amount'] as num? ?? 0,
                      ),
                      _buildTotalRow(
                        'MwSt (${(calculations['vat_rate'] as num? ?? 0).toStringAsFixed(1)}%):',
                        calculations['vat_amount'] as num? ?? 0,
                      ),
                      pw.Divider(color: PdfColors.blueGrey300),
                      _buildTotalRow(
                        'Gesamtbetrag:',
                        calculations['total'] as num? ?? 0,
                        isBold: true,
                        fontSize: 12,
                      ),
                    ],
                  ),
                ),
              ),

              // Footer bleibt gleich...
              pw.Expanded(child: pw.SizedBox()),
              pw.Container(
                padding: const pw.EdgeInsets.only(top: 20),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.blueGrey200, width: 0.5),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Florinett AG',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                        pw.Text('Tonewood Switzerland',
                            style: const pw.TextStyle(color: PdfColors.blueGrey600)),
                        pw.Text('Veja Zinols 6',
                            style: const pw.TextStyle(color: PdfColors.blueGrey600)),
                        pw.Text('7482 Bergün',
                            style: const pw.TextStyle(color: PdfColors.blueGrey600)),
                        pw.Text('Switzerland',
                            style: const pw.TextStyle(color: PdfColors.blueGrey600)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('phone: +41 81 407 21 34',
                            style: const pw.TextStyle(color: PdfColors.blueGrey600)),
                        pw.Text('e-mail: info@tonewood.ch',
                            style: const pw.TextStyle(color: PdfColors.blueGrey600)),
                        pw.Text('VAT: CHE-102.853.600 MWST',
                            style: const pw.TextStyle(color: PdfColors.blueGrey600)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

// Neue Hilfsmethode für Gesamtbeträge
  pw.Widget _buildTotalRow(
      String label,
      num amount, {
        bool isDiscount = false,
        bool isBold = false,
        double fontSize = 10,
      }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : null,
              color: PdfColors.blueGrey800,
            ),
          ),
          pw.Text(
            isDiscount
                ? '-${amount.toStringAsFixed(2)} CHF'
                : '${amount.toStringAsFixed(2)} CHF',
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : null,
              color: isDiscount ? PdfColors.red : PdfColors.blueGrey800,
            ),
          ),
        ],
      ),
    );
  }

// Hilfsmethoden für einheitliche Zellen-Formatierung
  pw.Widget _buildHeaderCell(String text,double fontSize, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
  fontSize:fontSize,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blueGrey800,
        ),
        textAlign: align,
      ),
    );
  }

  pw.Widget _buildContentCell(pw.Widget content) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: content,
    );
  }




  Future<void> _sendReceiptEmail(
      String receiptId,
      Uint8List pdfBytes,
      String recipientEmail,
      ) async {
    try {
      // Hole die PDF-URL aus dem Storage
      final receiptDoc = await FirebaseFirestore.instance
          .collection('sales_receipts')
          .doc(receiptId)
          .get();

      final pdfUrl = receiptDoc.data()?['pdf_url'];

      if (pdfUrl != null) {
        final emailContent = '''
Sehr geehrte Damen und Herren,

vielen Dank für Ihren Einkauf. Im Anhang finden Sie Ihren Lieferschein.

Mit freundlichen Grüßen
Ihr Team''';

        // Formatiere die URI-Komponenten separat
        final subject = Uri.encodeComponent('Ihr Lieferschein Nr. $receiptId');
        final body = Uri.encodeComponent('$emailContent\n\nLieferschein: $pdfUrl');

        // Baue die mailto-URI
        final emailUrl = 'mailto:$recipientEmail?subject=$subject&body=$body';
        final uri = Uri.parse(emailUrl);

        // Debug-Ausgabe
        print('Versuche E-Mail-Client zu öffnen mit URI: $uri');

        // Prüfe ob die URI geöffnet werden kann
        if (await canLaunchUrl(uri)) {
          // Versuche die URI zu öffnen
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );

          if (launched) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('E-Mail-Client wurde geöffnet'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            throw 'E-Mail-Client konnte nicht gestartet werden';
          }
        } else {
          // Alternative Methode versuchen
          final altUri = Uri(
            scheme: 'mailto',
            path: recipientEmail,
            queryParameters: {
              'subject': 'Ihr Lieferschein Nr. $receiptId',
              'body': '$emailContent\n\nLieferschein: $pdfUrl',
            },
          );

          print('Versuche alternative URI: $altUri');

          if (await canLaunchUrl(altUri)) {
            final launched = await launchUrl(
              altUri,
              mode: LaunchMode.externalApplication,
            );

            if (!launched) {
              throw 'Alternative Methode fehlgeschlagen';
            }
          } else {
            throw 'Kein E-Mail-Client verfügbar';
          }
        }
      } else {
        throw 'PDF-URL nicht gefunden';
      }
    } catch (e) {
      print('Fehler beim E-Mail-Versand: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Öffnen des E-Mail-Clients: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Details',
              textColor: Colors.white,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Fehlerdetails'),
                    content: SingleChildScrollView(
                      child: Text('$e'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Schließen'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }
    }
  }

  // Share-Funktion
  Future<void> _shareCsv(String receiptId, Uint8List? csvBytes) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/Bestellung_$receiptId.csv');
      await tempFile.writeAsBytes(csvBytes!);

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        subject: 'Bestellung CSV',
      );

      // Optional: Lösche die temporäre Datei nach einer Weile
      Future.delayed(const Duration(minutes: 5), () async {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Teilen der CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  Future<void> _shareReceipt(String receiptId, Uint8List pdfBytes) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/Lieferschein_$receiptId.pdf');
      await tempFile.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        subject: 'Lieferschein',
      );

      // Optional: Lösche die temporäre Datei nach einer Weile
      Future.delayed(const Duration(minutes: 5), () async {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Teilen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String> saveReceiptLocally(Uint8List pdfBytes, String receiptId) async {
    String filePath = '';
    try {
      final fileName = 'receipt_$receiptId.pdf';
      final downloadedPath = await DownloadHelper.downloadFile(pdfBytes, fileName);

      if (mounted) {
        if (kIsWeb) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF wird heruntergeladen...'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (downloadedPath != null) {
          filePath = downloadedPath;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gespeichert unter: $filePath'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    return filePath;
  }
  String? encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

Widget _buildSelectedProductInfo() {
  if (selectedProduct == null) return const SizedBox.shrink();

  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          selectedProduct!['product_name'] ?? 'Unbekanntes Produkt',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        FutureBuilder<int>(
          future: _getAvailableQuantity(selectedProduct!['barcode']),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Text(
                'Verfügbar: ${snapshot.data} ${selectedProduct!['unit'] ?? 'Stück'}',
              );
            }
            return const CircularProgressIndicator();
          },
        ),
        Text(
          'Preis: ${selectedProduct!['price_CHF']?.toStringAsFixed(2) ?? '0.00'} CHF',
        ),
      ],
    ),
  );
}

Widget _buildCheckoutButton() {
  return StreamBuilder<QuerySnapshot>(
    stream: _basketStream,
    builder: (context, snapshot) {
      final hasItems = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          onPressed: !hasItems || isLoading ? null : _processTransaction,
          icon: isLoading
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Icon(Icons.check),
          label: const Text('Verkauf abschließen'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      );
    },
  );
}



// Neue Zustandsvariablen für die Klasse
  double _vatRate = 8.1;
  Discount _totalDiscount = const Discount();
  Map<String, Discount> _itemDiscounts = {};

// Methode zum Anpassen des Rabatts für einen Artikel
  void _showItemDiscountDialog(String itemId, double currentAmount) {
    final percentageController = TextEditingController(
        text: _itemDiscounts[itemId]?.percentage.toString() ?? '0.0'
    );
    final absoluteController = TextEditingController(
        text: _itemDiscounts[itemId]?.absolute.toString() ?? '0.0'
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rabatt eingeben'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: percentageController,
                    decoration: const InputDecoration(
                      labelText: 'Rabatt %',
                      suffixText: '%',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: absoluteController,
                    decoration: const InputDecoration(
                      labelText: 'Rabatt CHF',
                      suffixText: 'CHF',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<double>(
              stream: _calculateItemDiscount(
                currentAmount,
                double.tryParse(percentageController.text) ?? 0,
                double.tryParse(absoluteController.text) ?? 0,
              ),
              builder: (context, snapshot) {
                final discount = snapshot.data ?? 0.0;
                return Text(
                  'Rabattbetrag: ${discount.toStringAsFixed(2)} CHF',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _itemDiscounts[itemId] = Discount(
                  percentage: double.tryParse(percentageController.text) ?? 0,
                  absolute: double.tryParse(absoluteController.text) ?? 0,
                );
              });
              Navigator.pop(context);
            },
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    );
  }
  Stream<double> _calculateItemDiscount(
      double amount,
      double percentage,
      double absolute,
      ) {
    return Stream.value(
        (amount * (percentage / 100)) + absolute
    );
  }

// Methode für den Gesamtrabatt
  void _showTotalDiscountDialog() {
    final percentageController = TextEditingController(
        text: _totalDiscount.percentage.toString()
    );
    final absoluteController = TextEditingController(
        text: _totalDiscount.absolute.toString()
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gesamtrabatt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: percentageController,
                    decoration: const InputDecoration(
                      labelText: 'Rabatt %',
                      suffixText: '%',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: absoluteController,
                    decoration: const InputDecoration(
                      labelText: 'Rabatt CHF',
                      suffixText: 'CHF',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<double>(
              stream: _basketStream.map((snapshot) {
                final subtotal = snapshot.docs.fold<double>(
                  0.0,
                      (sum, doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return sum + (data['quantity'] as int) *
                        (data['price_per_unit'] as double);
                  },
                );
                final percentage = double.tryParse(percentageController.text) ?? 0;
                final absolute = double.tryParse(absoluteController.text) ?? 0;
                return (subtotal * (percentage / 100)) + absolute;
              }),
              builder: (context, snapshot) {
                final discount = snapshot.data ?? 0.0;
                return Text(
                  'Rabattbetrag: ${discount.toStringAsFixed(2)} CHF',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _totalDiscount = Discount(
                  percentage: double.tryParse(percentageController.text) ?? 0,
                  absolute: double.tryParse(absoluteController.text) ?? 0,
                );
              });
              Navigator.pop(context);
            },
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    );
  }

// MwSt-Satz Dialog
  void _showVatRateDialog() {
    final vatController = TextEditingController(text: _vatRate.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('MwSt-Satz ändern'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: vatController,
              decoration: const InputDecoration(
                labelText: 'MwSt-Satz',
                suffixText: '%',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newRate = double.tryParse(vatController.text) ?? 7.7;
              setState(() => _vatRate = newRate);

              // Optional: Als neuen Standard-Satz speichern
              try {
                await FirebaseFirestore.instance
                    .collection('settings')
                    .doc('default_vat')
                    .set({
                  'rate': newRate,
                  'last_modified': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
              } catch (e) {
                print('Fehler beim Speichern des MwSt-Satzes: $e');
              }

              if (mounted) Navigator.pop(context);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }




@override
void dispose() {
  _isLoading.dispose();
  _selectedFairNotifier.dispose();
  customerSearchController.dispose();
  barcodeController.dispose();
  quantityController.dispose();
  super.dispose();
}
}
