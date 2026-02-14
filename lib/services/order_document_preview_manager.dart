// File: services/order_document_preview_manager.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tonewood/services/swiss_rounding.dart';
import '../orders/order_model.dart';
import 'pdf_generators/quote_generator.dart';
import 'pdf_generators/invoice_generator.dart';
import 'pdf_generators/commercial_invoice_generator.dart';
import 'pdf_generators/delivery_note_generator.dart';
import 'pdf_generators/packing_list_generator.dart';
import 'preview_pdf_viewer_screen.dart';
import 'shipping_costs_manager.dart';
import '../services/icon_helper.dart';

class OrderDocumentPreviewManager {
  // ═══════════════════════════════════════════════════════════════════════════
  // HAUPT-METHODE: Zeige Dokument-Preview für einen Auftrag
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<void> showDocumentPreview({
    required BuildContext context,
    required OrderX order,
    required String documentType,
  }) async {
    print('=== showDocumentPreview RECEIVED ===');
    print('order.id: ${order.id}');
    print('order.costCenter: ${order.costCenter}');
    print('====================================');
    try {
      // Prüfe ob Einzelversand aktiv ist und HR/LS betroffen
      if (documentType == 'commercial_invoice_pdf' ||
          documentType == 'Handelsrechnung' ||
          documentType == 'delivery_note_pdf' ||
          documentType == 'Lieferschein') {
        final shipmentMode = await _getShipmentMode(order.id);

        if (shipmentMode == 'per_shipment') {
          // Einzelversand → Zeige Auswahl-Dialog für Versandgruppen
          await _showShipmentGroupPreviewSelector(
            context: context,
            order: order,
            documentType: documentType,
          );
          return;
        }
      }

      // Standard: Einzelnes Dokument preview
      await _showSingleDocumentPreview(
        context: context,
        order: order,
        documentType: documentType,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler bei der Preview: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EINZELVERSAND: Versandgruppen-Auswahl Dialog
  // ═══════════════════════════════════════════════════════════════════════════

  /// Lädt den Versandmodus aus der Packliste
  static Future<String> _getShipmentMode(String orderId) async {
    try {
      final packingListDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .collection('packing_list')
          .doc('settings')
          .get();

      if (packingListDoc.exists) {
        return packingListDoc.data()?['shipment_mode'] as String? ?? 'total';
      }
    } catch (e) {
      print('Fehler beim Laden des Versandmodus: $e');
    }
    return 'total';
  }

  /// Zeigt einen Dialog zur Auswahl der Versandgruppe für die Preview
  /// Zeigt einen Dialog zur Auswahl der Versandgruppe für die Preview
  static Future<void> _showShipmentGroupPreviewSelector({
    required BuildContext context,
    required OrderX order,
    required String documentType,
  }) async {
    // Lade Pakete und gruppiere sie
    final packages = await _loadPackages(order.id);
    if (packages.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keine Packstücke konfiguriert'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final shipmentGroups = _groupPackagesByShipment(packages);
    final sortedGroupNumbers = shipmentGroups.keys.toList()..sort();

    final isCommercialInvoice = documentType == 'commercial_invoice_pdf' ||
        documentType == 'Handelsrechnung';
    final docLabel = isCommercialInvoice ? 'Handelsrechnung' : 'Lieferschein';

    if (!context.mounted) return;

    // NEU: Speichere den äußeren Context
    final outerContext = context;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: Theme.of(sheetContext).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(sheetContext).colorScheme.outline.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  getAdaptiveIcon(
                    iconName: 'mail',
                    defaultIcon: Icons.mail,
                    color: Theme.of(sheetContext).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$docLabel Preview',
                          style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Einzelversand: ${sortedGroupNumbers.length} Sendungen',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(sheetContext).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // // Alle anzeigen Button
            // if (sortedGroupNumbers.length > 1)
            //   Padding(
            //     padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
            //     child: SizedBox(
            //       width: double.infinity,
            //       child: OutlinedButton.icon(
            //         onPressed: () async {
            //           Navigator.pop(sheetContext);
            //           await _showAllShipmentGroupPreviews(
            //             context: outerContext,
            //             order: order,
            //             documentType: documentType,
            //             shipmentGroups: shipmentGroups,
            //             sortedGroupNumbers: sortedGroupNumbers,
            //           );
            //         },
            //         icon: getAdaptiveIcon(
            //           iconName: 'visibility',
            //           defaultIcon: Icons.visibility,
            //           size: 18,
            //         ),
            //         label: Text('Alle ${sortedGroupNumbers.length} $docLabel${sortedGroupNumbers.length > 1 ? 'en' : ''} nacheinander'),
            //       ),
            //     ),
            //   ),

            // Einzelne Versandgruppen
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              itemCount: sortedGroupNumbers.length,
              itemBuilder: (context, index) {
                final groupNumber = sortedGroupNumbers[index];
                final groupPackages = shipmentGroups[groupNumber]!;
                final displayNumber = index + 1;

                // Items in dieser Versandgruppe zählen
                int itemCount = 0;
                for (final pkg in groupPackages) {
                  final items = pkg['items'] as List<dynamic>? ?? [];
                  itemCount += items.length;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _getShipmentGroupColor(groupNumber).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$displayNumber',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getShipmentGroupColor(groupNumber),
                          ),
                        ),
                      ),
                    ),
                    title: Text('$docLabel Sendung $displayNumber'),
                    subtitle: Text(
                      '${groupPackages.length} Paket${groupPackages.length > 1 ? 'e' : ''} • $itemCount Produkt${itemCount > 1 ? 'e' : ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: getAdaptiveIcon(
                      iconName: 'chevron_right',
                      defaultIcon: Icons.chevron_right,
                    ),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _showShipmentGroupPreview(
                        context: outerContext,
                        order: order,
                        documentType: documentType,
                        shipmentGroups: shipmentGroups,
                        allOrderItems: order.items,
                        groupNumber: groupNumber,
                        displayNumber: displayNumber,
                        totalGroups: sortedGroupNumbers.length,
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Zeigt alle Versandgruppen-Previews nacheinander
  static Future<void> _showAllShipmentGroupPreviews({
    required BuildContext context,
    required OrderX order,
    required String documentType,
    required Map<int, List<Map<String, dynamic>>> shipmentGroups,
    required List<int> sortedGroupNumbers,
  }) async {
    for (int i = 0; i < sortedGroupNumbers.length; i++) {
      if (!context.mounted) return;

      await _showShipmentGroupPreview(
        context: context,
        order: order,
        documentType: documentType,
        shipmentGroups: shipmentGroups,
        allOrderItems: order.items,
        groupNumber: sortedGroupNumbers[i],
        displayNumber: i + 1,
        totalGroups: sortedGroupNumbers.length,
      );
    }
  }

  /// Zeigt die Preview für eine einzelne Versandgruppe
  static Future<void> _showShipmentGroupPreview({
    required BuildContext context,
    required OrderX order,
    required String documentType,
    required Map<int, List<Map<String, dynamic>>> shipmentGroups,
    required List<Map<String, dynamic>> allOrderItems,
    required int groupNumber,
    required int displayNumber,
    required int totalGroups,
  }) async
  {
    try {
      // Loading anzeigen
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final orderData = await _loadOrderData(order);
      if (orderData == null) {
        if (context.mounted) Navigator.pop(context);
        return;
      }

      final groupPackages = shipmentGroups[groupNumber]!;

      // Items für diese Versandgruppe sammeln
      final groupItems = _getItemsForShipmentGroup(groupPackages, allOrderItems);

      // Anteilige Calculations
      final totalSubtotal = _calculateSubtotal(allOrderItems);
      final groupCalculations = _calculateProportionalDiscounts(
        packageItems: groupItems,
        totalSubtotal: totalSubtotal,
        originalCalculations: orderData['calculations'] as Map<String, dynamic>?,
      );

      // Tara-Daten
      final groupTaraData = _calculateGroupTaraData(groupPackages);

      if (context.mounted) Navigator.pop(context); // Loading schließen

      final isCommercialInvoice = documentType == 'commercial_invoice_pdf' ||
          documentType == 'Handelsrechnung';

      if (isCommercialInvoice) {
        await _showShipmentCommercialInvoicePreview(
          context: context,
          orderData: orderData,
          order: order,
          groupItems: groupItems,
          groupCalculations: groupCalculations,
          groupTaraData: groupTaraData,
          displayNumber: displayNumber,
          totalGroups: totalGroups,
        );
      } else {
        await _showShipmentDeliveryNotePreview(
          context: context,
          orderData: orderData,
          order: order,
          groupItems: groupItems,
          displayNumber: displayNumber,
          totalGroups: totalGroups,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Loading schließen falls noch offen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler bei Preview Sendung $displayNumber: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Preview: Handelsrechnung für eine Versandgruppe
  static Future<void> _showShipmentCommercialInvoicePreview({
    required BuildContext context,
    required Map<String, dynamic> orderData,
    required OrderX order,
    required List<Map<String, dynamic>> groupItems,
    required Map<String, dynamic> groupCalculations,
    required Map<String, dynamic> groupTaraData,
    required int displayNumber,
    required int totalGroups,
  }) async {
    final customer = orderData['customer'] as Map<String, dynamic>;
    final language = orderData['metadata']?['language'] ?? customer['language'] ?? 'DE';
    final metadata = orderData['metadata'] ?? {};

    final rawExchangeRates = metadata['exchangeRates'] ?? {'CHF': 1.0};
    final exchangeRates = <String, double>{};
    rawExchangeRates.forEach((key, value) {
      if (value is int) {
        exchangeRates[key as String] = value.toDouble();
      } else if (value is double) {
        exchangeRates[key as String] = value;
      } else {
        exchangeRates[key as String] = 1.0;
      }
    });

    final costCenterCode = orderData['costCenter']?['code'] ?? '00000';
    final taraSettingsRaw = await _loadOrderTaraSettings(order.id);

    final currency = taraSettingsRaw['commercial_invoice_currency'] ?? metadata['currency'] ?? 'CHF';

    // Tara-Settings: Überschreibe mit Gruppen-Daten
    final taraSettings = {
      'number_of_packages': groupTaraData['number_of_packages'],
      'packaging_weight': groupTaraData['packaging_weight'],
      'packaging_volume': groupTaraData['packaging_volume'],
      'commercial_invoice_date': taraSettingsRaw['commercial_invoice_date'],
      'commercial_invoice_origin_declaration': taraSettingsRaw['commercial_invoice_origin_declaration'],
      'commercial_invoice_cites': taraSettingsRaw['commercial_invoice_cites'],
      'commercial_invoice_export_reason': taraSettingsRaw['commercial_invoice_export_reason'],
      'commercial_invoice_export_reason_text': taraSettingsRaw['commercial_invoice_export_reason_text'],
      'commercial_invoice_incoterms': taraSettingsRaw['commercial_invoice_incoterms'],
      'commercial_invoice_selected_incoterms': taraSettingsRaw['commercial_invoice_selected_incoterms'],
      'commercial_invoice_incoterms_freetexts': taraSettingsRaw['commercial_invoice_incoterms_freetexts'],
      'commercial_invoice_delivery_date':
      taraSettingsRaw['commercial_invoice_delivery_date'] == true ||
          taraSettingsRaw['use_as_delivery_date'] == true,
      'commercial_invoice_delivery_date_value': taraSettingsRaw['use_as_delivery_date'] == true
          ? taraSettingsRaw['commercial_invoice_date']
          : taraSettingsRaw['commercial_invoice_delivery_date_value'],
      'commercial_invoice_delivery_date_month_only': taraSettingsRaw['use_as_delivery_date'] == true
          ? false
          : (taraSettingsRaw['commercial_invoice_delivery_date_month_only'] ?? false),
      'commercial_invoice_carrier': taraSettingsRaw['commercial_invoice_carrier'],
      'commercial_invoice_carrier_text': taraSettingsRaw['commercial_invoice_carrier_text'],
      'commercial_invoice_signature': taraSettingsRaw['commercial_invoice_signature'],
      'commercial_invoice_selected_signature': taraSettingsRaw['commercial_invoice_selected_signature'],
    };

    DateTime? invoiceDate;
    if (taraSettingsRaw['commercial_invoice_date'] != null) {
      final dateValue = taraSettingsRaw['commercial_invoice_date'];
      if (dateValue is Timestamp) {
        invoiceDate = dateValue.toDate();
      } else if (dateValue is DateTime) {
        invoiceDate = dateValue;
      }
    }

    final rawVatRate = metadata['vatRate'] ?? 8.1;
    final vatRate = (rawVatRate is int) ? rawVatRate.toDouble() : rawVatRate as double;
    final taxOption = metadata['taxOption'] ?? 0;

    final orderAdditionalTexts = metadata['additionalTexts'] as Map<String, dynamic>?;

    final pdfBytes = await CommercialInvoiceGenerator.generateCommercialInvoicePdf(
      items: groupItems,
      customerData: customer,
      fairData: orderData['fair'],
      costCenterCode: costCenterCode,
      currency: currency,
      exchangeRates: exchangeRates,
      language: language,
      invoiceNumber: '${order.orderNumber}-CI-$displayNumber',
      shippingCosts: null, // Keine Versandkosten auf Einzel-HR
      calculations: groupCalculations,
      taxOption: taxOption,
      vatRate: vatRate,
      taraSettings: taraSettings,
      invoiceDate: invoiceDate,
      additionalTexts: orderAdditionalTexts,
    );

    if (context.mounted) {
      _openPdfViewer(
        context,
        pdfBytes,
        'HR_${order.orderNumber}_Sendung_$displayNumber.pdf',
      );
    }
  }

  /// Preview: Lieferschein für eine Versandgruppe
  static Future<void> _showShipmentDeliveryNotePreview({
    required BuildContext context,
    required Map<String, dynamic> orderData,
    required OrderX order,
    required List<Map<String, dynamic>> groupItems,
    required int displayNumber,
    required int totalGroups,
  }) async {
    final customer = orderData['customer'] as Map<String, dynamic>;
    final language = orderData['metadata']?['language'] ?? customer['language'] ?? 'DE';
    final metadata = orderData['metadata'] ?? {};
    final currency = metadata['currency'] ?? 'CHF';
    final exchangeRates = Map<String, double>.from(metadata['exchangeRates'] ?? {'CHF': 1.0});
    final costCenterCode = orderData['costCenter']?['code'] ?? '00000';

    final deliverySettings = await _loadOrderDeliverySettings(order.id);
    final orderAdditionalTexts = metadata['additionalTexts'] as Map<String, dynamic>?;

    final pdfBytes = await DeliveryNoteGenerator.generateDeliveryNotePdf(
      items: groupItems,
      customerData: customer,
      fairData: orderData['fair'],
      costCenterCode: costCenterCode,
      currency: currency,
      exchangeRates: exchangeRates,
      language: language,
      deliveryNoteNumber: '${order.orderNumber}-LS-$displayNumber',
      deliveryDate: deliverySettings['delivery_date'],
      paymentDate: deliverySettings['payment_date'],
      additionalTexts: orderAdditionalTexts,
    );

    if (context.mounted) {
      _openPdfViewer(
        context,
        pdfBytes,
        'LS_${order.orderNumber}_Sendung_$displayNumber.pdf',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPER: Items pro Versandgruppe (aus PostalDocumentService übernommen)
  // ═══════════════════════════════════════════════════════════════════════════

  static String _getItemKey(Map<String, dynamic> item) {
    return item['basket_doc_id']?.toString() ?? '';
  }

  static List<Map<String, dynamic>> _loadPackagesSync(List<dynamic> rawPackages) {
    return rawPackages.map((p) => Map<String, dynamic>.from(p as Map)).toList();
  }

  static Future<List<Map<String, dynamic>>> _loadPackages(String orderId) async {
    try {
      final packingListDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .collection('packing_list')
          .doc('settings')
          .get();

      if (!packingListDoc.exists) return [];

      final data = packingListDoc.data()!;
      final packages = data['packages'] as List<dynamic>? ?? [];
      return packages.map((p) => Map<String, dynamic>.from(p as Map)).toList();
    } catch (e) {
      print('Fehler beim Laden der Packages: $e');
      return [];
    }
  }

  static Map<int, List<Map<String, dynamic>>> _groupPackagesByShipment(
      List<Map<String, dynamic>> packages,
      ) {
    final Map<int, List<Map<String, dynamic>>> groups = {};
    for (int i = 0; i < packages.length; i++) {
      final group = (packages[i]['shipment_group'] as num?)?.toInt() ?? (i + 1);
      groups.putIfAbsent(group, () => []);
      groups[group]!.add(packages[i]);
    }
    return groups;
  }

  static List<Map<String, dynamic>> _getItemsForShipmentGroup(
      List<Map<String, dynamic>> groupPackages,
      List<Map<String, dynamic>> allOrderItems,
      ) {
    final Map<String, Map<String, dynamic>> mergedItems = {};

    for (final package in groupPackages) {
      final packageItemsList = package['items'] as List<dynamic>? ?? [];

      for (final pkgItem in packageItemsList) {
        final pkgItemMap = Map<String, dynamic>.from(pkgItem as Map);
        final pkgItemKey = _getItemKey(pkgItemMap);
        final packageQuantity = (pkgItemMap['quantity'] as num?)?.toDouble() ?? 0.0;

        if (packageQuantity <= 0) continue;

        // Finde das entsprechende Order-Item per itemKey
        final orderItem = allOrderItems.firstWhere(
              (item) => _getItemKey(item) == pkgItemKey,
          orElse: () => <String, dynamic>{},
        );

        if (orderItem.isEmpty) continue;

        if (mergedItems.containsKey(pkgItemKey)) {
          final existing = mergedItems[pkgItemKey]!;
          final existingQty = (existing['quantity'] as num?)?.toDouble() ?? 0.0;
          existing['quantity'] = existingQty + packageQuantity;

          // Einzelrabatt addieren
          final originalQuantity = (orderItem['quantity'] as num?)?.toDouble() ?? 1.0;
          final originalDiscountAmount = (orderItem['discount_amount'] as num?)?.toDouble() ?? 0.0;
          if (originalDiscountAmount > 0 && originalQuantity > 0) {
            final discountPerUnit = originalDiscountAmount / originalQuantity;
            final existingDiscount = (existing['discount_amount'] as num?)?.toDouble() ?? 0.0;
            existing['discount_amount'] = existingDiscount + (discountPerUnit * packageQuantity);
          }
        } else {
          final itemCopy = Map<String, dynamic>.from(orderItem);
          itemCopy['quantity'] = packageQuantity;

          // Einzelrabatt proportional anpassen
          final originalQuantity = (orderItem['quantity'] as num?)?.toDouble() ?? 1.0;
          final originalDiscountAmount = (orderItem['discount_amount'] as num?)?.toDouble() ?? 0.0;
          if (originalDiscountAmount > 0 && originalQuantity > 0) {
            final discountPerUnit = originalDiscountAmount / originalQuantity;
            itemCopy['discount_amount'] = discountPerUnit * packageQuantity;
          }

          mergedItems[pkgItemKey] = itemCopy;
        }
      }
    }

    return mergedItems.values.toList();
  }

  static double _calculateSubtotal(List<Map<String, dynamic>> items) {
    double subtotal = 0.0;
    for (final item in items) {
      if (item['is_service'] == true) continue;
      if (item['is_gratisartikel'] == true) continue;
      final quantity = (item['quantity'] as num? ?? 0).toDouble();
      final pricePerUnit = (item['custom_price_per_unit'] as num?) != null
          ? (item['custom_price_per_unit'] as num).toDouble()
          : (item['price_per_unit'] as num? ?? 0).toDouble();
      subtotal += quantity * pricePerUnit;
    }
    return subtotal;
  }

  static Map<String, dynamic> _calculateProportionalDiscounts({
    required List<Map<String, dynamic>> packageItems,
    required double totalSubtotal,
    required Map<String, dynamic>? originalCalculations,
  }) {
    if (originalCalculations == null) return {};
    final calculations = Map<String, dynamic>.from(originalCalculations);
    final packageSubtotal = _calculateSubtotal(packageItems);
    final proportion = totalSubtotal > 0 ? packageSubtotal / totalSubtotal : 0.0;
    final totalDiscountAmount = (calculations['total_discount_amount'] as num?)?.toDouble() ?? 0.0;
    if (totalDiscountAmount > 0) {
      calculations['total_discount_amount'] = totalDiscountAmount * proportion;
    }
    return calculations;
  }

  static Map<String, dynamic> _calculateGroupTaraData(
      List<Map<String, dynamic>> groupPackages,
      ) {
    double totalTareWeight = 0.0;
    double totalVolume = 0.0;
    for (final package in groupPackages) {
      totalTareWeight += (package['tare_weight'] as num?)?.toDouble() ?? 0.0;
      final width = (package['width'] as num?)?.toDouble() ?? 0.0;
      final height = (package['height'] as num?)?.toDouble() ?? 0.0;
      final length = (package['length'] as num?)?.toDouble() ?? 0.0;
      totalVolume += (width * height * length) / 1000000;
    }
    return {
      'number_of_packages': groupPackages.length,
      'packaging_weight': totalTareWeight,
      'packaging_volume': totalVolume,
    };
  }

  /// Farbkodierung für Versandgruppen
  static Color _getShipmentGroupColor(int group) {
    const colors = [
      Color(0xFF1976D2),
      Color(0xFF388E3C),
      Color(0xFFF57C00),
      Color(0xFF7B1FA2),
      Color(0xFFD32F2F),
      Color(0xFF00838F),
      Color(0xFF5D4037),
      Color(0xFF455A64),
      Color(0xFFC2185B),
      Color(0xFF689F38),
    ];
    return colors[(group - 1) % colors.length];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STANDARD PREVIEW (Gesamtversand, wie bisher)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> _showSingleDocumentPreview({
    required BuildContext context,
    required OrderX order,
    required String documentType,
  }) async {
    try {
      // Zeige Loading-Dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Lade Auftragsdaten
      final orderData = await _loadOrderData(order);

      if (context.mounted) {
        Navigator.pop(context); // Schließe Loading-Dialog
      }

      if (orderData == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fehler beim Laden der Auftragsdaten'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Generiere entsprechendes PDF
      switch (documentType) {
        case 'quote_pdf':
        case 'Angebot':
          await _showQuotePreview(context, orderData, order);
          break;
        case 'invoice_pdf':
        case 'Rechnung':
          await _showInvoicePreview(context, orderData, order);
          break;
        case 'commercial_invoice_pdf':
        case 'Handelsrechnung':
          await _showCommercialInvoicePreview(context, orderData, order);
          break;
        case 'delivery_note_pdf':
        case 'Lieferschein':
          await _showDeliveryNotePreview(context, orderData, order);
          break;
        case 'packing_list_pdf':
        case 'Packliste':
          await _showPackingListPreview(context, orderData, order);
          break;
        default:
          _showNotImplementedMessage(context, documentType);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler bei der Preview: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BESTEHENDE METHODEN (unverändert)
  // ═══════════════════════════════════════════════════════════════════════════

  // Lade Auftragsdaten
  static Future<Map<String, dynamic>?> _loadOrderData(OrderX order) async {
    try {
      final metadata = order.metadata;

      // Lade Quote-Daten falls vorhanden
      Map<String, dynamic>? quoteData;
      if (order.quoteId != null && order.quoteId!.isNotEmpty) {
        final quoteDoc = await FirebaseFirestore.instance
            .collection('quotes')
            .doc(order.quoteId)
            .get();
        if (quoteDoc.exists) {
          quoteData = quoteDoc.data();
        }
      }

      // CostCenter: Erst aus Order, dann Fallback auf Quote
      Map<String, dynamic>? costCenter = order.costCenter;
      if (costCenter == null && quoteData != null && quoteData['costCenter'] != null) {
        costCenter = quoteData['costCenter'];
      }

      // Fair: Erst aus Metadata, dann aus Quote
      Map<String, dynamic>? fair = metadata['fairData'] as Map<String, dynamic>?;
      if (fair == null && quoteData != null && quoteData['fair'] != null) {
        fair = quoteData['fair'];
      }

      return {
        'order': order,
        'customer': order.customer,
        'items': order.items,
        'calculations': order.calculations,
        'metadata': metadata,
        'costCenter': costCenter,
        'fair': fair,
        'quoteData': quoteData,
      };
    } catch (e) {
      print('Fehler beim Laden der Auftragsdaten: $e');
      return null;
    }
  }

  // Preview für Angebot
  static Future<void> _showQuotePreview(
      BuildContext context,
      Map<String, dynamic> orderData,
      OrderX order,
      ) async {
    try {
      final customer = orderData['customer'] as Map<String, dynamic>;
      final language = orderData['metadata']?['language'] ?? customer['language'] ?? 'DE';
      final metadata = orderData['metadata'] ?? {};
      final shippingCosts = metadata['shippingCosts'] ?? {};
      final roundingSettings = await SwissRounding.loadRoundingSettings();
      final currency = metadata['currency'] ?? 'CHF';
      final exchangeRates = Map<String, double>.from(metadata['exchangeRates'] ?? {'CHF': 1.0});
      final costCenterCode = orderData['costCenter']?['code'] ?? '00000';

      final pdfBytes = await QuoteGenerator.generateQuotePdf(
        roundingSettings: roundingSettings,
        items: orderData['items'],
        customerData: customer,
        fairData: orderData['fair'],
        costCenterCode: costCenterCode,
        currency: currency,
        exchangeRates: exchangeRates,
        language: language,
        quoteNumber: order.quoteNumber ?? 'PREVIEW',
        shippingCosts: shippingCosts,
        calculations: orderData['calculations'],
        taxOption: metadata['taxOption'] ?? 0,
        vatRate: (metadata['vatRate'] ?? 8.1).toDouble(),
      );

      if (context.mounted) {
        _openPdfViewer(context, pdfBytes, 'Angebot_${order.quoteNumber}.pdf');
      }
    } catch (e) {
      print('Fehler bei Angebot-Preview: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> _loadOrderInvoiceSettings(String orderId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .collection('settings')
          .doc('invoice_settings')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        return {
          'down_payment_amount': data['down_payment_amount'] ?? 0.0,
          'down_payment_reference': data['down_payment_reference'] ?? '',
          'down_payment_date': data['down_payment_date'] != null
              ? (data['down_payment_date'] as Timestamp).toDate()
              : null,
        };
      }
    } catch (e) {
      print('Fehler beim Laden der Rechnungs-Einstellungen: $e');
    }

    return {
      'down_payment_amount': 0.0,
      'down_payment_reference': '',
      'down_payment_date': null,
    };
  }

  // Preview für Rechnung
  static Future<void> _showInvoicePreview(
      BuildContext context,
      Map<String, dynamic> orderData,
      OrderX order,
      ) async {
    try {
      final customer = orderData['customer'] as Map<String, dynamic>;
      final language = orderData['metadata']?['language'] ?? customer['language'] ?? 'DE';
      final metadata = orderData['metadata'] ?? {};
      final shippingCosts = metadata['shippingCosts'] ?? {};
      final currency = metadata['currency'] ?? 'CHF';
      final exchangeRates = Map<String, double>.from(metadata['exchangeRates'] ?? {'CHF': 1.0});
      final costCenterCode = orderData['costCenter']?['code'] ?? '00000';

      final invoiceSettings = await _loadOrderInvoiceSettings(order.id);
      final roundingSettings = await SwissRounding.loadRoundingSettings();
      final orderAdditionalTexts = metadata['additionalTexts'] as Map<String, dynamic>?;

      final pdfBytes = await InvoiceGenerator.generateInvoicePdf(
        items: orderData['items'],
        customerData: customer,
        fairData: orderData['fair'],
        costCenterCode: costCenterCode,
        currency: currency,
        exchangeRates: exchangeRates,
        language: language,
        invoiceNumber: order.orderNumber,
        shippingCosts: shippingCosts,
        calculations: orderData['calculations'],
        paymentTermDays: 30,
        taxOption: metadata['taxOption'] ?? 0,
        vatRate: (metadata['vatRate'] ?? 8.1).toDouble(),
        downPaymentSettings: invoiceSettings,
        roundingSettings: roundingSettings,
        additionalTexts: orderAdditionalTexts,
      );

      if (context.mounted) {
        _openPdfViewer(context, pdfBytes, 'Rechnung_${order.orderNumber}.pdf');
      }
    } catch (e, stackTrace) {
      print('Fehler bei Rechnung-Preview: $e\n$stackTrace');
      rethrow;
    }
  }

  // Preview für Handelsrechnung (Gesamtversand)
  static Future<void> _showCommercialInvoicePreview(
      BuildContext context,
      Map<String, dynamic> orderData,
      OrderX order,
      ) async {
    try {
      final customer = orderData['customer'] as Map<String, dynamic>;
      final language = orderData['metadata']?['language'] ?? customer['language'] ?? 'DE';
      final metadata = orderData['metadata'] ?? {};
      final shippingCosts = metadata['shippingCosts'] ?? {};

      final rawExchangeRates = metadata['exchangeRates'] ?? {'CHF': 1.0};
      final exchangeRates = <String, double>{};
      rawExchangeRates.forEach((key, value) {
        if (value is int) {
          exchangeRates[key as String] = value.toDouble();
        } else if (value is double) {
          exchangeRates[key as String] = value;
        } else {
          exchangeRates[key as String] = 1.0;
        }
      });

      final costCenterCode = orderData['costCenter']?['code'] ?? '00000';
      final taraSettings = await _loadOrderTaraSettings(order.id);
      final currency = taraSettings['commercial_invoice_currency'] ?? metadata['currency'] ?? 'CHF';

      DateTime? invoiceDate;
      if (taraSettings['commercial_invoice_date'] != null) {
        final dateValue = taraSettings['commercial_invoice_date'];
        if (dateValue is Timestamp) {
          invoiceDate = dateValue.toDate();
        } else if (dateValue is DateTime) {
          invoiceDate = dateValue;
        }
      }

      final rawVatRate = metadata['vatRate'] ?? 8.1;
      final vatRate = (rawVatRate is int) ? rawVatRate.toDouble() : rawVatRate as double;
      final taxOption = metadata['taxOption'] ?? 0;

      final orderAdditionalTexts = metadata['additionalTexts'] as Map<String, dynamic>?;

      final pdfBytes = await CommercialInvoiceGenerator.generateCommercialInvoicePdf(
        items: orderData['items'],
        customerData: customer,
        fairData: orderData['fair'],
        costCenterCode: costCenterCode,
        currency: currency,
        exchangeRates: exchangeRates,
        language: language,
        invoiceNumber: '${order.orderNumber}-CI',
        shippingCosts: shippingCosts,
        calculations: orderData['calculations'],
        taxOption: taxOption,
        vatRate: vatRate,
        taraSettings: taraSettings,
        invoiceDate: invoiceDate,
        additionalTexts: orderAdditionalTexts,
      );

      if (context.mounted) {
        _openPdfViewer(context, pdfBytes, 'Handelsrechnung_${order.orderNumber}.pdf');
      }
    } catch (e, stackTrace) {
      print('Fehler bei Handelsrechnung-Preview: $e\n$stackTrace');
      rethrow;
    }
  }

  // Preview für Lieferschein (Gesamtversand)
  static Future<void> _showDeliveryNotePreview(
      BuildContext context,
      Map<String, dynamic> orderData,
      OrderX order,
      ) async {
    try {
      final customer = orderData['customer'] as Map<String, dynamic>?;
      final language = orderData['metadata']?['language'] ?? customer?['language'] ?? 'DE';
      final metadata = orderData['metadata'] as Map<String, dynamic>?;
      final currency = metadata?['currency'] ?? 'CHF';
      final exchangeRates = Map<String, double>.from(metadata?['exchangeRates'] ?? {'CHF': 1.0});
      final costCenter = orderData['costCenter'];
      final costCenterCode = costCenter?['code'] ?? '00000';

      final items = orderData['items'];
      final fairData = orderData['fair'];

      final deliverySettings = await _loadOrderDeliverySettings(order.id);
      final orderAdditionalTexts = orderData['metadata']?['additionalTexts'] as Map<String, dynamic>?;

      final pdfBytes = await DeliveryNoteGenerator.generateDeliveryNotePdf(
        items: items,
        customerData: customer!,
        fairData: fairData,
        costCenterCode: costCenterCode,
        currency: currency,
        exchangeRates: exchangeRates,
        language: language,
        deliveryNoteNumber: '${order.orderNumber}-LS',
        deliveryDate: deliverySettings['delivery_date'],
        paymentDate: deliverySettings['payment_date'],
        additionalTexts: orderAdditionalTexts,
      );

      if (context.mounted) {
        _openPdfViewer(context, pdfBytes, 'Lieferschein_${order.orderNumber}.pdf');
      }
    } catch (e, stackTrace) {
      print('Fehler bei Lieferschein-Preview: $e\n$stackTrace');
      rethrow;
    }
  }

  // Preview für Packliste
  static Future<void> _showPackingListPreview(
      BuildContext context,
      Map<String, dynamic> orderData,
      OrderX order,
      ) async {
    try {
      final customer = orderData['customer'] as Map<String, dynamic>;
      final language = orderData['metadata']?['language'] ?? customer['language'] ?? 'DE';
      final costCenterCode = orderData['costCenter']?['code'] ?? '00000';

      final packingListDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id)
          .collection('packing_list')
          .doc('settings')
          .get();

      if (!packingListDoc.exists) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Keine Packliste konfiguriert'),
              content: const Text(
                  'Für diesen Auftrag wurde noch keine Packliste konfiguriert. '
                      'Bitte erstelle zuerst eine Packliste über "Dokumente erstellen".'
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      final pdfBytes = await PackingListGenerator.generatePackingListPdf(
        language: language,
        packingListNumber: '${order.orderNumber}-PL',
        customerData: customer,
        fairData: orderData['fair'],
        costCenterCode: costCenterCode,
        orderId: order.id,
      );

      if (context.mounted) {
        _openPdfViewer(context, pdfBytes, 'Packliste_${order.orderNumber}.pdf');
      }
    } catch (e) {
      print('Fehler bei Packliste-Preview: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SETTINGS LADEN
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> _loadOrderTaraSettings(String orderId) async {
    try {
      final orderSettingsDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .collection('settings')
          .doc('tara_settings')
          .get();

      Map<String, dynamic> settings = {};
      if (orderSettingsDoc.exists) {
        settings = orderSettingsDoc.data() ?? {};
      }

      // Lade Verpackungsgewicht aus Packliste
      double packagingWeight = 0.0;
      double packagingVolume = 0.0;
      int numberOfPackages = settings['number_of_packages'] ?? 1;

      try {
        final packingListDoc = await FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .collection('packing_list')
            .doc('settings')
            .get();

        if (packingListDoc.exists) {
          final data = packingListDoc.data()!;
          final packages = data['packages'] as List<dynamic>? ?? [];
          if (packages.isNotEmpty) {
            numberOfPackages = packages.length;
            for (final package in packages) {
              packagingWeight += (package['tare_weight'] as num?)?.toDouble() ?? 0.0;
              final width = (package['width'] as num?)?.toDouble() ?? 0.0;
              final height = (package['height'] as num?)?.toDouble() ?? 0.0;
              final length = (package['length'] as num?)?.toDouble() ?? 0.0;
              final volumeM3 = (width * height * length) / 1000000;
              packagingVolume += volumeM3;
            }
          }
        }
      } catch (e) {
        print('Fehler beim Laden des Verpackungsgewichts aus Packliste: $e');
      }

      settings['number_of_packages'] = numberOfPackages;
      settings['packaging_weight'] = packagingWeight;
      settings['packaging_volume'] = packagingVolume;
      return settings;
    } catch (e) {
      print('Fehler beim Laden der Tara-Einstellungen: $e');
      return {'number_of_packages': 1, 'packaging_weight': 0.0};
    }
  }

  static Future<Map<String, DateTime?>> _loadOrderDeliverySettings(String orderId) async {
    try {
      final orderSettingsDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .collection('settings')
          .doc('delivery_settings')
          .get();

      if (orderSettingsDoc.exists) {
        final data = orderSettingsDoc.data()!;
        return {
          'delivery_date': data['delivery_date'] != null
              ? (data['delivery_date'] as Timestamp).toDate()
              : null,
          'payment_date': data['payment_date'] != null
              ? (data['payment_date'] as Timestamp).toDate()
              : null,
        };
      }

      return {'delivery_date': null, 'payment_date': null};
    } catch (e) {
      print('Fehler beim Laden der Lieferschein-Einstellungen: $e');
      return {'delivery_date': null, 'payment_date': null};
    }
  }

  // PDF Viewer öffnen
  static void _openPdfViewer(BuildContext context, Uint8List pdfBytes, String fileName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PreviewPDFViewerScreen(
          pdfBytes: pdfBytes,
          title: fileName,
        ),
      ),
    );
  }

  // Nicht implementiert Nachricht
  static void _showNotImplementedMessage(BuildContext context, String documentType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$documentType Preview'),
        content: Text('Die Preview für $documentType ist noch nicht implementiert.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}