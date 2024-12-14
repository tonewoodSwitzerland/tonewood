import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'models/sales_filter.dart';

class SalesList extends StatefulWidget {
  final SalesFilter filter;

  const SalesList({
    Key? key,
    required this.filter,
  }) : super(key: key);

  @override
  SalesListState createState() => SalesListState();
}

class SalesListState extends State<SalesList> {
  final _scrollController = ScrollController();
  bool _isLoadingMore = false;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoadingMore) {
      _loadMoreData();
    }
  }

  Future<void> _loadMoreData() async {
    setState(() => _isLoadingMore = true);
    // TODO: Implementiere Lazy Loading Logik
    setState(() => _isLoadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildQuery().snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Fehler: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final sales = snapshot.data!.docs;

        if (sales.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.point_of_sale, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  'Keine Verkäufe gefunden',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: sales.length + (_isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == sales.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final doc = sales[index];
            final data = doc.data() as Map<String, dynamic>;
            final customer = data['customer'] as Map<String, dynamic>;
            final items = (data['items'] as List).cast<Map<String, dynamic>>();
            final metadata = data['metadata'] as Map<String, dynamic>;
            final calculations = data['calculations'] as Map<String, dynamic>;
            final timestamp = (metadata['timestamp'] as Timestamp).toDate();

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                onTap: () => _showSaleDetails(doc.id, data),
                contentPadding: const EdgeInsets.all(8),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer['company'] ?? 'Unbekannter Kunde',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd.MM.yyyy HH:mm').format(timestamp),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          NumberFormat.currency(
                            locale: 'de_CH',
                            symbol: 'CHF',
                          ).format(calculations['total']),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${items.length} ${items.length == 1 ? 'Artikel' : 'Artikel'}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Artikel-Info
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.inventory_2,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${items.length} ${items.length == 1 ? 'Artikel' : 'Artikel'}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Messe-Info wenn vorhanden
                        if (metadata['fairId'] != null)
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('fairs')
                                .doc(metadata['fairId'] as String)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const SizedBox();
                              }
                              final fairData = snapshot.data!.data() as Map<String, dynamic>?;
                              if (fairData == null) return const SizedBox();

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.event_available,
                                      size: 16,
                                      color: Colors.blue[700],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Messe: ${fairData['name']}',
                                      style: TextStyle(
                                        color: Colors.blue[700],
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),

                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('sales_receipts')
        .orderBy('metadata.timestamp', descending: true)
        .limit(_pageSize);

    if (widget.filter.startDate != null) {
      query = query.where('metadata.timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(widget.filter.startDate!));
    }
    if (widget.filter.endDate != null) {
      final endOfDay = DateTime(
        widget.filter.endDate!.year,
        widget.filter.endDate!.month,
        widget.filter.endDate!.day,
        23, 59, 59,
      );
      query = query.where('metadata.timestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
    }

    // Kundenfilter
    if (widget.filter.selectedCustomers != null) {
      final customerId = widget.filter.selectedCustomers.toString().replaceAll(RegExp(r'[\[\]]'), '');
      query = query.where('customer.id', isEqualTo: customerId);
    }

    // Messefilter
    if (widget.filter.selectedFairs != null) {
      final fairId = widget.filter.selectedFairs.toString().replaceAll(RegExp(r'[\[\]]'), '');
      query = query.where('metadata.fairId', isEqualTo: fairId);
    }

    // Produktfilter
    if (widget.filter.selectedProducts != null) {
      final productId = widget.filter.selectedProducts.toString().replaceAll(RegExp(r'[\[\]]'), '');


      // Debug: Prüfe die Struktur eines Verkaufsdokuments
      FirebaseFirestore.instance
          .collection('sales_receipts')
          .limit(1)
          .get()
          .then((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final doc = snapshot.docs.first.data();

          // Prüfe, wie Produkt-IDs gespeichert sind
          final items = doc['items'] as List<dynamic>;
          for (var item in items) {

          }
        }
      });

      // Versuche verschiedene Möglichkeiten, wie die Produkt-ID gespeichert sein könnte
      query = query.where('items', arrayContainsAny: [
        {'product_id': productId},               // Fall 1: Als Objekt im Array
        productId,                               // Fall 2: Direkt als ID
        {'id': productId},                       // Fall 3: Als id-Feld
      ]);

      // Debug: Teste die Query
      query.get().then((snapshot) {

        if (snapshot.docs.isNotEmpty) {
          final doc = snapshot.docs.first.data();
        ;
        }
      });
    }

    // Debug output

    query.get().then((snapshot) {

      if (snapshot.docs.isEmpty) {

      } else {
        final firstDoc = snapshot.docs.first.data();

      }
    });

    return query;
  }

  void _showSaleDetails(String receiptId, Map<String, dynamic> data) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
      final customer = data['customer'] as Map<String, dynamic>;
      final items = (data['items'] as List).cast<Map<String, dynamic>>();
      final metadata = data['metadata'] as Map<String, dynamic>;
      final calculations = data['calculations'] as Map<String, dynamic>;
      final timestamp = (metadata['timestamp'] as Timestamp).toDate();

      return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
    height: MediaQuery.of(context).size.height * 0.8,
    padding: const EdgeInsets.all(24),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    // Header
    Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
    Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    const Text(
    'Verkaufsdetails',
    style: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    ),
    ),
    Text(
    'Nr. $receiptId',
    style: TextStyle(
    color: Colors.grey[600],
    fontSize: 14,
    ),
    ),
    ],
    ),
    IconButton(
    icon: const Icon(Icons.close),
    onPressed: () => Navigator.pop(context),
    ),
    ],
    ),
    const SizedBox(height: 16),

    // Kunde und Datum
    Row(
    children: [
    Expanded(
    flex: 3,
    child: Card(
    child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Row(
    children: [
    Icon(Icons.business,
    size: 16,
    color: Theme.of(context).primaryColor),
    const SizedBox(width: 8),
    const Text('Kunde',
    style: TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    )),
    ],
    ),
    const SizedBox(height: 8),
    Text(
    customer['company'] ?? '',
    style: const TextStyle(fontSize: 13),
    ),
    Text(
    customer['fullName'] ?? '',
    style: TextStyle(
    fontSize: 12,
    color: Colors.grey[600],
    ),
    ),
    Text(
    customer['address'] ?? '',
    style: TextStyle(
    fontSize: 12,
    color: Colors.grey[600],
    ),
    ),
    ],
    ),
    ),
    ),
    ),
    const SizedBox(width: 8),
    Expanded(
    flex: 2,
    child: Card(
    child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Row(
    children: [
    Icon(Icons.calendar_today,
    size: 16,
    color: Theme.of(context).primaryColor),
    const SizedBox(width: 8),
    const Text('Datum',
    style: TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    )),
    ],
    ),
    const SizedBox(height: 8),
    Text(
    DateFormat('dd.MM.yyyy').format(timestamp),
    style: const TextStyle(fontSize: 13),
    ),
    Text(
    DateFormat('HH:mm').format(timestamp),
    style: TextStyle(
    fontSize: 12,
    color: Colors.grey[600],
    ),
    ),
    ],
    ),
    ),
    ),
    ),
    ],
    ),
    const SizedBox(height: 16),

    // Artikelliste
    Expanded(
    child: Card(
    child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Row(
    children: [
    Icon(Icons.shopping_cart,
    size: 16,
    color: Theme.of(context).primaryColor),
    const SizedBox(width: 8),
    Text(
    'Artikel (${items.length})',
    style: const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    ),
    ),
    ],
    ),
    const SizedBox(height: 16),

    // Spaltentitel
    Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
    border: Border(
    bottom: BorderSide(color: Colors.grey.shade300),
    ),
    ),
    child: const Row(
    children: [
    Expanded(flex: 3, child: Text('Produkt', style: TextStyle(fontWeight: FontWeight.bold))),
    Expanded(child: Text('Anz.', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
    Expanded(flex: 3, child: Text('Preis', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
    ],
    ),
    ),

    // Artikelliste
    Expanded(
    child: ListView.builder(
    itemCount: items.length,
    itemBuilder: (context, index) {
    final item = items[index];
    final quantity = item['quantity'] as int;
    final pricePerUnit = item['price_per_unit'] as double;
    final subtotal = quantity * pricePerUnit;
    final discount = item['discount'] as Map<String, dynamic>?;
    final discountAmount = item['discount_amount'] as double? ?? 0.0;
    final total = item['total'] as double? ?? subtotal;

    return Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
    border: Border(
    bottom: BorderSide(color: Colors.grey.shade200),
    ),
    ),
    child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Expanded(
    flex: 3,
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text(
    item['product_name'] ?? '',
    style: const TextStyle(fontWeight: FontWeight.w500),
    ),
    const SizedBox(height: 2),
    Text(
    item['quality_name'] ?? '',
    style: TextStyle(

    color: Colors.grey[600],
      fontSize: 12,
    ),
    ),
    ],
    ),
    ),
      Expanded(
        child: Text(
          '$quantity',
          textAlign: TextAlign.center,
        ),
      ),
      Expanded(
        flex: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${pricePerUnit.toStringAsFixed(2)} CHF/${item['unit']}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            Text(
              '${subtotal.toStringAsFixed(2)} CHF',
              style: TextStyle(
                decoration: discountAmount > 0 ? TextDecoration.lineThrough : null,
                color: discountAmount > 0 ? Colors.grey : null,
                fontSize: 13,
              ),
            ),
            if (discountAmount > 0) ...[
              if (discount?['percentage'] != null && discount!['percentage'] > 0)
                Text(
                  '- ${discount['percentage']}%',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              Text(
                '- ${discountAmount.toStringAsFixed(2)} CHF',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
              Text(
                '${total.toStringAsFixed(2)} CHF',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    ],
    ),
    );
    },
    ),
    ),

      // Summenbereich
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Zwischensumme:', style: TextStyle(color: Colors.grey[600])),
                Text(
                  '${calculations['subtotal'].toStringAsFixed(2)} CHF',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            if ((calculations['item_discounts'] as double? ?? 0.0) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Positionsrabatte:',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    Text(
                      '- ${calculations['item_discounts'].toStringAsFixed(2)} CHF',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ),
              ),
            if ((calculations['total_discount_amount'] as double? ?? 0.0) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Gesamtrabatt:',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    Text(
                      '- ${calculations['total_discount_amount'].toStringAsFixed(2)} CHF',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Nettobetrag:'),
                  Text('${calculations['net_amount'].toStringAsFixed(2)} CHF'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('MwSt (${calculations['vat_rate'].toStringAsFixed(1)}%):'),
                  Text('${calculations['vat_amount'].toStringAsFixed(2)} CHF'),
                ],
              ),
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Gesamtbetrag:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${calculations['total'].toStringAsFixed(2)} CHF',
                  style: const TextStyle(fontWeight: FontWeight.bold),
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

      // Aktionsbuttons
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (data['pdf_url'] != null && data['pdf_url'].toString().isNotEmpty)
            ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('PDF Beleg'),
              onPressed: () async {
                await _shareReceipt(receiptId, data['pdf_url']);
                Navigator.pop(context);
              },
            ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.table_chart),
            label: const Text('CSV Export'),
            onPressed: () async {
              await _exportToCsv(receiptId, data);
            },
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

  Future<void> _shareReceipt(String receiptId, String fileUrl) async {
    try {
      if (fileUrl.isEmpty) {
        throw 'Keine Export-URL verfügbar';
      }

      setState(() => _isLoadingMore = true);

      final response = await http.get(Uri.parse(fileUrl));
      if (response.statusCode != 200) {
        throw 'Fehler beim Laden der Datei (Status ${response.statusCode})';
      }

      final tempDir = await getTemporaryDirectory();

      // Bestimme den Dateityp basierend auf dem Content-Type Header
      final contentType = response.headers['content-type'];
      String extension;
      String prefix;

      if (contentType?.contains('csv') == true || fileUrl.toLowerCase().endsWith('.csv')) {
        extension = 'csv';
        prefix = 'CSV_Export';
      } else {
        extension = 'pdf';
        prefix = 'Beleg';
      }

      final tempFile = File('${tempDir.path}/${prefix}_$receiptId.$extension');
      await tempFile.writeAsBytes(response.bodyBytes);

      final fileName = '${prefix}_$receiptId.$extension';

      await Share.shareXFiles(
        [XFile(tempFile.path, name: fileName)],
        subject: '$prefix Nr. $receiptId',
      );

      // Lösche die temporäre Datei nach 5 Minuten
      Future.delayed(const Duration(minutes: 5), () async {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      });

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }
  // Neue Methode für CSV Export
  Future<void> _exportToCsv(String receiptId, Map<String, dynamic> data) async {
    try {
      final customer = data['customer'] as Map<String, dynamic>;
      final items = (data['items'] as List).cast<Map<String, dynamic>>();
      final metadata = data['metadata'] as Map<String, dynamic>;
      final calculations = data['calculations'] as Map<String, dynamic>;
      final timestamp = (metadata['timestamp'] as Timestamp).toDate();

      // CSV Header
      final csvData = [
        // Header Zeile
        [
          'Datum',
          'Belegnummer',
          'Kunde',
          'Artikel',
          'Qualität',
          'Menge',
          'Einheit',
          'Einzelpreis',
          'Rabatt %',
          'Rabatt CHF',
          'Total',
        ].join(';'),
      ];

      // Artikel Zeilen
      for (final item in items) {
        final row = [
          DateFormat('dd.MM.yyyy').format(timestamp),
          receiptId,
          customer['company'],
          item['product_name'],
          item['quality_name'],
          item['quantity'].toString(),
          item['unit'],
          item['price_per_unit'].toStringAsFixed(2),
          (item['discount']?['percentage'] ?? 0).toString(),
          (item['discount_amount'] ?? 0).toStringAsFixed(2),
          item['total'].toStringAsFixed(2),
        ].join(';');

        csvData.add(row);
      }

      // Zusammenfassung am Ende
      csvData.addAll([
        '', // Leerzeile
        [
          '',
          '',
          '',
          'Zwischensumme',
          '',
          '',
          '',
          '',
          '',
          '',
          calculations['subtotal'].toStringAsFixed(2),
        ].join(';'),
        [
          '',
          '',
          '',
          'Rabatte',
          '',
          '',
          '',
          '',
          '',
          '',
          '- ${calculations['total_discount_amount'].toStringAsFixed(2)}',
        ].join(';'),
        [
          '',
          '',
          '',
          'MwSt ${calculations['vat_rate'].toStringAsFixed(1)}%',
          '',
          '',
          '',
          '',
          '',
          '',
          calculations['vat_amount'].toStringAsFixed(2),
        ].join(';'),
        [
          '',
          '',
          '',
          'Gesamtbetrag',
          '',
          '',
          '',
          '',
          '',
          '',
          calculations['total'].toStringAsFixed(2),
        ].join(';'),
      ]);

      // Erstelle temporäre Datei
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/Verkauf_$receiptId.csv');

      // Füge BOM für Excel hinzu
      final List<int> bom = [0xEF, 0xBB, 0xBF];
      final csvString = csvData.join('\n');
      await tempFile.writeAsBytes(bom + utf8.encode(csvString));

      // Teile die Datei
      await Share.shareXFiles(
        [XFile(tempFile.path, name: 'Verkauf_$receiptId.csv')],
        subject: 'Verkauf Nr. $receiptId',
      );

      // Lösche die temporäre Datei nach 5 Minuten
      Future.delayed(const Duration(minutes: 5), () async {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      });

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim CSV-Export: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}