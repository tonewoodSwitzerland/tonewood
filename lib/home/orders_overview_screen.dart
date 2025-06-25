import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/order_model.dart';
import '../services/icon_helper.dart';

// Zentrale Farbdefinitionen
class OrderColors {
  static const pending = Color(0xFFEF9A3C);      // Warmes Gelb-Orange
  static const processing = Color(0xFF2196F3);    // Material Blue
  static const shipped = Color(0xFF7C4DFF);       // Material Deep Purple
  static const delivered = Color(0xFF4CAF50);     // Material Green
  static const cancelled = Color(0xFF757575);     // Material Grey

  static const paymentPending = Color(0xFFFF7043);  // Deep Orange
  static const paymentPartial = Color(0xFFFFA726);  // Orange
  static const paymentPaid = Color(0xFF66BB6A);     // Light Green
}

class OrdersOverviewScreen extends StatefulWidget {
  const OrdersOverviewScreen({Key? key}) : super(key: key);

  @override
  State<OrdersOverviewScreen> createState() => _OrdersOverviewScreenState();
}

class _OrdersOverviewScreenState extends State<OrdersOverviewScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  OrderStatus? _filterStatus;
  PaymentStatus? _filterPaymentStatus;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Aufträge', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          // Filter-Button für Status
          PopupMenuButton<dynamic>(
            icon: Badge(
              isLabelVisible: _filterStatus != null || _filterPaymentStatus != null,
              label: const Text('!'),
              child: getAdaptiveIcon(iconName: 'filter_list', defaultIcon: Icons.filter_list),
            ),
            onSelected: (value) {
              if (value is OrderStatus?) {
                setState(() {
                  _filterStatus = value;
                });
              } else if (value is PaymentStatus?) {
                setState(() {
                  _filterPaymentStatus = value;
                });
              } else if (value == 'clear_all') {
                setState(() {
                  _filterStatus = null;
                  _filterPaymentStatus = null;
                });
              }
            },
            itemBuilder: (context) => [
              if (_filterStatus != null || _filterPaymentStatus != null)
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.clear, size: 20),
                      SizedBox(width: 8),
                      Text('Filter zurücksetzen'),
                    ],
                  ),
                ),
              if (_filterStatus != null || _filterPaymentStatus != null)
                const PopupMenuDivider(),
              const PopupMenuItem(
                enabled: false,
                child: Text('Auftragsstatus:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const PopupMenuItem(
                value: null,
                child: Text('Alle Status'),
              ),
              ...OrderStatus.values.map((status) => PopupMenuItem(
                value: status,
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getStatusColor(status),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(status.displayName),
                  ],
                ),
              )),
              const PopupMenuDivider(),
              const PopupMenuItem(
                enabled: false,
                child: Text('Zahlungsstatus:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              ...PaymentStatus.values.map((status) => PopupMenuItem(
                value: status,
                child: Row(
                  children: [
                    Icon(Icons.euro, size: 16, color: _getPaymentStatusColor(status)),
                    const SizedBox(width: 8),
                    Text(status.displayName, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              )),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Suchleiste
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Suche nach Kunde, Auftragsnummer...',
                hintStyle: const TextStyle(fontSize: 14),
                prefixIcon: getAdaptiveIcon(iconName: 'search', defaultIcon: Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Kompakte Statistik-Karten
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildCompactStatistics(),
          ),

          // Auftragsliste
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildOrdersQuery(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Fehler: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final orders = snapshot.data!.docs
                    .map((doc) => OrderX.fromFirestore(doc))
                    .where((order) {
                  // Suchfilter
                  if (_searchQuery.isNotEmpty) {
                    final searchLower = _searchQuery.toLowerCase();
                    return order.orderNumber.toLowerCase().contains(searchLower) ||
                        order.customer['company'].toString().toLowerCase().contains(searchLower) ||
                        order.customer['fullName'].toString().toLowerCase().contains(searchLower);
                  }
                  return true;
                })
                    .toList();

                if (orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Keine Aufträge gefunden',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _buildCompactOrderCard(order);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatistics() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 60);

        final orders = snapshot.data!.docs
            .map((doc) => OrderX.fromFirestore(doc))
            .toList();

        final openOrders = orders.where((o) =>
        o.status != OrderStatus.delivered &&
            o.status != OrderStatus.cancelled
        ).length;

        final unpaidOrders = orders.where((o) =>
        o.paymentStatus != PaymentStatus.paid
        ).length;

        return Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _buildCompactStatCard(
                  'Offen',
                  openOrders.toString(),
                  Icons.schedule,
                  OrderColors.pending,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactStatCard(
                  'Unbezahlt',
                  unpaidOrders.toString(),
                  Icons.euro_outlined,
                  OrderColors.paymentPending,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: color,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: color.withOpacity(0.8),
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _buildOrdersQuery() {
    Query query = FirebaseFirestore.instance.collection('orders');

    if (_filterStatus != null) {
      query = query.where('status', isEqualTo: _filterStatus!.name);
    }

    if (_filterPaymentStatus != null) {
      query = query.where('paymentStatus', isEqualTo: _filterPaymentStatus!.name);
    }

    return query.orderBy('orderDate', descending: true).snapshots();
  }

  Widget _buildCompactOrderCard(OrderX order) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isDarkMode ? 2 : 1,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
          width: 0.5,
        ),
      ),
      child: InkWell(
        onTap: () => _showOrderDetails(order),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Erste Zeile: Auftragsnummer, Datum, Status
              Row(
                children: [
                  // Auftragsnummer & Datum
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Auftrag ${order.orderNumber}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              DateFormat('dd.MM.yy').format(order.orderDate),
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            // Zeige Angebotsnummer wenn vorhanden
                            if (order.quoteNumber != null && order.quoteNumber!.isNotEmpty) ...[
                              Text(
                                ' • ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(
                                    Icons.description_outlined,
                                    size: 11,
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Angebot ${order.quoteNumber}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Status-Chips
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildCompactStatusChip(order.status),
                      const SizedBox(height: 4),
                      _buildCompactPaymentChip(order.paymentStatus),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Zweite Zeile: Kunde & Betrag
              Row(
                children: [
                  // Kunde
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                            Icons.business_outlined,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            order.customer['company'] ?? order.customer['fullName'] ?? 'Unbekannter Kunde',
                            style: const TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Betrag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: OrderColors.delivered.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'CHF ${(order.calculations['total'] as num? ?? 0).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: OrderColors.delivered,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Aktionen
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Status ändern
                  _buildCompactActionButton(
                    icon: Icons.edit_outlined,
                    onPressed: () => _showQuickStatusMenu(order),
                    tooltip: 'Status ändern',
                  ),
                  const SizedBox(width: 4),
                  // History
                  _buildCompactActionButton(
                    icon: Icons.history,
                    onPressed: () => _showOrderHistory(order),
                    tooltip: 'Verlauf',
                  ),
                  const SizedBox(width: 4),
                  // Dokumente
                  _buildCompactActionButton(
                    icon: Icons.folder_outlined,
                    onPressed: () => _viewOrderDocuments(order),
                    tooltip: 'Dokumente',
                  ),
                  const SizedBox(width: 4),
                  // Teilen
                  _buildCompactActionButton(
                    icon: Icons.share_outlined,
                    onPressed: () => _shareOrder(order),
                    tooltip: 'Teilen',
                  ),
                  if (order.status == OrderStatus.pending || order.status == OrderStatus.processing) ...[
                    const SizedBox(width: 4),
                    _buildCompactActionButton(
                      icon: Icons.cancel_outlined,
                      onPressed: () => _releaseOrder(order),
                      tooltip: 'Stornieren',
                      color: Colors.red,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

// Diese Hilfsfunktionen werden nicht mehr benötigt, da wir direkt auf order.quoteNumber zugreifen können

// Hilfsfunktionen für sicheren Zugriff auf die Angebotsnummer
  bool _hasQuoteNumber(OrderX order) {
    // Prüfe verschiedene Möglichkeiten
    if (order.quoteNumber != null && order.quoteNumber!.isNotEmpty) {
      return true;
    }

    // Prüfe in metadata
    if (order.metadata != null &&
        order.metadata!['quoteNumber'] != null &&
        order.metadata!['quoteNumber'].toString().isNotEmpty) {
      return true;
    }

    // Prüfe ob quoteId vorhanden ist
    if (order.quoteId != null && order.quoteId!.isNotEmpty) {
      return true;
    }

    return false;
  }

  String _getQuoteNumberFromOrder(OrderX order) {
    // Versuche zuerst direkt auf quoteNumber zuzugreifen
    if (order.quoteNumber != null && order.quoteNumber!.isNotEmpty) {
      return order.quoteNumber!;
    }

    // Dann in metadata
    if (order.metadata != null && order.metadata!['quoteNumber'] != null) {
      return order.metadata!['quoteNumber'].toString();
    }

    // Falls nur quoteId vorhanden ist, extrahiere die Nummer daraus
    // QuoteId Format: Q-YYYY-NNNN
    if (order.quoteId != null && order.quoteId!.startsWith('Q-')) {
      return order.quoteId!.substring(2); // Entferne "Q-" Präfix
    }

    return 'Unbekannt';
  }

  Widget _buildCompactActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    Color? color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Tooltip(
          message: tooltip,
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              size: 18,
              color: color ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactStatusChip(OrderStatus status) {
    final color = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            status.displayName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactPaymentChip(PaymentStatus status) {
    final color = _getPaymentStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.euro, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            status.displayName,
            style: TextStyle(
              fontSize: 10,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return OrderColors.pending;
      case OrderStatus.processing:
        return OrderColors.processing;
      case OrderStatus.shipped:
        return OrderColors.shipped;
      case OrderStatus.delivered:
        return OrderColors.delivered;
      case OrderStatus.cancelled:
        return OrderColors.cancelled;
    }
  }

  Color _getPaymentStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return OrderColors.paymentPending;
      case PaymentStatus.partial:
        return OrderColors.paymentPartial;
      case PaymentStatus.paid:
        return OrderColors.paymentPaid;
    }
  }

  void _showOrderDetails(OrderX order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  getAdaptiveIcon(iconName: 'shopping_bag', defaultIcon: Icons.shopping_bag),
                  const SizedBox(width: 10),
                  Text(
                    'Auftrag ${order.orderNumber}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Auftragsinformationen
                    _buildInfoSection('Auftragsinformationen', [
                      _buildInfoRow('Auftragsnummer:', order.orderNumber),
                      _buildInfoRow('Datum:', DateFormat('dd.MM.yyyy HH:mm').format(order.orderDate)),
                      _buildInfoRow('Status:', order.status.displayName),
                      _buildInfoRow('Zahlungsstatus:', order.paymentStatus.displayName),
                    ]),

                    const SizedBox(height: 20),

                    // Kundeninformationen
                    _buildInfoSection('Kunde', [
                      _buildInfoRow('Firma:', order.customer['company'] ?? '-'),
                      _buildInfoRow('Name:', order.customer['fullName'] ?? '-'),
                      _buildInfoRow('E-Mail:', order.customer['email'] ?? '-'),
                      _buildInfoRow('Adresse:', '${order.customer['street']} ${order.customer['houseNumber']}, ${order.customer['zipCode']} ${order.customer['city']}'),
                    ]),

                    const SizedBox(height: 20),

                    // Artikel
                    Text(
                      'Artikel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...order.items.map((item) {
                      final quantity = item['quantity'] as num? ?? 0;
                      final pricePerUnit = item['price_per_unit'] as num? ?? 0;
                      final total = item['total'] as num? ?? (quantity * pricePerUnit);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['product_name']?.toString() ?? 'Unbekanntes Produkt',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text('Menge: $quantity ${item['unit']?.toString() ?? 'Stück'}'),
                              Text('Preis: CHF ${pricePerUnit.toStringAsFixed(2)}'),
                              Text('Gesamt: CHF ${total.toStringAsFixed(2)}'),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 20),

                    // Berechnungen
                    _buildInfoSection('Berechnungen', [
                      _buildInfoRow('Zwischensumme:', 'CHF ${(order.calculations['subtotal'] as num? ?? 0).toStringAsFixed(2)}'),
                      if ((order.calculations['item_discounts'] as num? ?? 0) > 0)
                        _buildInfoRow('Positionsrabatte:', 'CHF -${(order.calculations['item_discounts'] as num? ?? 0).toStringAsFixed(2)}'),
                      if ((order.calculations['total_discount_amount'] as num? ?? 0) > 0)
                        _buildInfoRow('Gesamtrabatt:', 'CHF -${(order.calculations['total_discount_amount'] as num? ?? 0).toStringAsFixed(2)}'),
                      _buildInfoRow('Nettobetrag:', 'CHF ${(order.calculations['net_amount'] as num? ?? 0).toStringAsFixed(2)}'),
                      _buildInfoRow('MwSt:', 'CHF ${(order.calculations['vat_amount'] as num? ?? 0).toStringAsFixed(2)}'),
                      _buildInfoRow('Gesamtbetrag:', 'CHF ${(order.calculations['total'] as num? ?? 0).toStringAsFixed(2)}', isTotal: true),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : null,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickStatusMenu(OrderX order) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.only(top: 20, bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header mit Overflow-Schutz
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'Status ändern',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      'Auftrag ${order.orderNumber}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Scrollbare Liste für viele Einträge
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Auftragsstatus
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Icon(Icons.assignment, size: 16, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Auftragsstatus',
                            style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...OrderStatus.values.map((status) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                      dense: true,
                      leading: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _getStatusColor(status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(status.displayName, style: const TextStyle(fontSize: 14)),
                      trailing: order.status == status
                          ? Icon(Icons.check_circle, color: _getStatusColor(status), size: 20)
                          : null,
                      onTap: () async {
                        Navigator.pop(context);
                        await _updateOrderStatusValue(order, status);
                      },
                    )),

                    const Divider(height: 24, indent: 20, endIndent: 20),

                    // Zahlungsstatus
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Icon(Icons.payments, size: 16, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Zahlungsstatus',
                            style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...PaymentStatus.values.map((status) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                      dense: true,
                      leading: Icon(Icons.euro, size: 16, color: _getPaymentStatusColor(status)),
                      title: Text(status.displayName, style: const TextStyle(fontSize: 14)),
                      trailing: order.paymentStatus == status
                          ? Icon(Icons.check_circle, color: _getPaymentStatusColor(status), size: 20)
                          : null,
                      onTap: () async {
                        Navigator.pop(context);
                        await _updatePaymentStatusValue(order, status);
                      },
                    )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateOrderStatusValue(OrderX order, OrderStatus status) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final batch = FirebaseFirestore.instance.batch();

      // Update Order
      final orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id);

      batch.update(orderRef, {
        'status': status.name,
        'status_updated_at': FieldValue.serverTimestamp(),
      });

      // Create History Entry
      final historyRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id)
          .collection('history')
          .doc();

      batch.set(historyRef, {
        'timestamp': FieldValue.serverTimestamp(),
        'user_id': user?.uid ?? 'unknown',
        'user_email': user?.email ?? 'Unknown User',
        'user_name': user?.displayName ?? user?.email?.split('@')[0] ?? 'Unknown',
        'action': 'status_change',
        'changes': {
          'field': 'status',
          'old_value': order.status.name,
          'new_value': status.name,
          'old_display': order.status.displayName,
          'new_display': status.displayName,
        },
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auftragsstatus wurde auf ${status.displayName} geändert'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  Future<void> _updatePaymentStatusValue(OrderX order, PaymentStatus status) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final batch = FirebaseFirestore.instance.batch();

      // Update Order
      final orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id);

      batch.update(orderRef, {
        'paymentStatus': status.name,
        'payment_updated_at': FieldValue.serverTimestamp(),
      });

      // Create History Entry
      final historyRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id)
          .collection('history')
          .doc();

      batch.set(historyRef, {
        'timestamp': FieldValue.serverTimestamp(),
        'user_id': user?.uid ?? 'unknown',
        'user_email': user?.email ?? 'Unknown User',
        'user_name': user?.displayName ?? user?.email?.split('@')[0] ?? 'Unknown',
        'action': 'payment_status_change',
        'changes': {
          'field': 'paymentStatus',
          'old_value': order.paymentStatus.name,
          'new_value': status.name,
          'old_display': order.paymentStatus.displayName,
          'new_display': status.displayName,
        },
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Zahlungsstatus wurde auf ${status.displayName} geändert'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  void _showOrderHistory(OrderX order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.history),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Verlauf - ${order.orderNumber}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(),

            // History List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .doc(order.id)
                    .collection('history')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    // Zeige die Erstellung des Auftrags als ersten Eintrag
                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _buildHistoryEntry(
                          icon: Icons.add_circle_outline,
                          color: Colors.green,
                          title: 'Auftrag erstellt',
                          subtitle: 'Initiale Erstellung des Auftrags',
                          timestamp: order.orderDate,
                          userName: 'System',
                        ),
                      ],
                    );
                  }

                  final historyEntries = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: historyEntries.length + 1, // +1 für Erstellungs-Eintrag
                    itemBuilder: (context, index) {
                      // Erster Eintrag ist immer die Erstellung
                      if (index == historyEntries.length) {
                        return _buildHistoryEntry(
                          icon: Icons.add_circle_outline,
                          color: Colors.green,
                          title: 'Auftrag erstellt',
                          subtitle: 'Initiale Erstellung des Auftrags',
                          timestamp: order.orderDate,
                          userName: 'System',
                        );
                      }

                      final data = historyEntries[index].data() as Map<String, dynamic>;
                      final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                      final userName = data['user_name'] ?? 'Unknown';
                      final action = data['action'] ?? '';
                      final changes = data['changes'] as Map<String, dynamic>? ?? {};

                      // Bestimme Icon und Farbe basierend auf der Aktion
                      IconData icon;
                      Color color;
                      String title;
                      String subtitle;

                      switch (action) {
                        case 'status_change':
                          icon = Icons.swap_horiz;
                          color = _getStatusColor(OrderStatus.values.firstWhere(
                                (s) => s.name == changes['new_value'],
                            orElse: () => OrderStatus.pending,
                          ));
                          title = 'Status geändert';
                          subtitle = '${changes['old_display']} → ${changes['new_display']}';
                          break;
                        case 'payment_status_change':
                          icon = Icons.payment;
                          color = _getPaymentStatusColor(PaymentStatus.values.firstWhere(
                                (s) => s.name == changes['new_value'],
                            orElse: () => PaymentStatus.pending,
                          ));
                          title = 'Zahlungsstatus geändert';
                          subtitle = '${changes['old_display']} → ${changes['new_display']}';
                          break;
                        case 'order_cancelled':
                          icon = Icons.cancel;
                          color = Colors.red;
                          title = 'Auftrag storniert';
                          subtitle = data['reason'] ?? 'Manuell storniert';
                          break;
                        default:
                          icon = Icons.info_outline;
                          color = Colors.grey;
                          title = 'Änderung';
                          subtitle = action;
                      }

                      return _buildHistoryEntry(
                        icon: icon,
                        color: color,
                        title: title,
                        subtitle: subtitle,
                        timestamp: timestamp,
                        userName: userName,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildHistoryEntry({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required DateTime timestamp,
    required String userName,
  }) {
    final timeAgo = _getTimeAgo(timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline Line
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.3), width: 2),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      userName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return DateFormat('dd.MM.yyyy HH:mm').format(timestamp);
    } else if (difference.inDays > 0) {
      return 'vor ${difference.inDays} Tag${difference.inDays == 1 ? '' : 'en'}';
    } else if (difference.inHours > 0) {
      return 'vor ${difference.inHours} Stunde${difference.inHours == 1 ? '' : 'n'}';
    } else if (difference.inMinutes > 0) {
      return 'vor ${difference.inMinutes} Minute${difference.inMinutes == 1 ? '' : 'n'}';
    } else {
      return 'gerade eben';
    }
  }



  void _viewOrderDocuments(OrderX order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  getAdaptiveIcon(iconName: 'folder_open', defaultIcon: Icons.folder_open),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Dokumente - ${order.orderNumber}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(),

            // Content
            Expanded(
              child: order.documents.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Keine Dokumente verfügbar',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: order.documents.length,
                itemBuilder: (context, index) {
                  final entry = order.documents.entries.elementAt(index);
                  final docType = entry.key;
                  final docUrl = entry.value;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getDocumentTypeColor(docType).withOpacity(0.1),
                        child: Icon(
                          _getDocumentTypeIcon(docType),
                          color: _getDocumentTypeColor(docType),
                        ),
                      ),
                      title: Text(_getDocumentTypeName(docType)),
                      subtitle: Text(_getDocumentTypeDescription(docType)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility, size: 20),
                            onPressed: () => _openDocument(docUrl),
                            tooltip: 'Öffnen',
                          ),
                          IconButton(
                            icon: const Icon(Icons.share, size: 20),
                            onPressed: () => _shareDocument(docUrl, docType, order.orderNumber),
                            tooltip: 'Weiterleiten',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getDocumentTypeColor(String docType) {
    if (docType.contains('quote')) return Colors.blue;
    if (docType.contains('invoice')) return Colors.green;
    if (docType.contains('delivery')) return Colors.purple;
    if (docType.contains('packing')) return Colors.orange;
    return Colors.grey;
  }

  IconData _getDocumentTypeIcon(String docType) {
    if (docType.contains('pdf')) return Icons.picture_as_pdf;
    if (docType.contains('csv')) return Icons.table_chart;
    return Icons.description;
  }

  String _getDocumentTypeName(String docType) {
    switch (docType) {
      case 'quote_pdf':
        return 'Angebot';
      case 'invoice_pdf':
        return 'Rechnung';
      case 'delivery-note_pdf':
        return 'Lieferschein';
      case 'commercial-invoice_pdf':
        return 'Handelsrechnung';
      case 'packing-list_pdf':
        return 'Packliste';
      default:
        return docType.replaceAll('_', ' ').replaceAll('-', ' ');
    }
  }

  String _getDocumentTypeDescription(String docType) {
    switch (docType) {
      case 'quote_pdf':
        return 'PDF-Dokument des ursprünglichen Angebots';
      case 'invoice_pdf':
        return 'PDF-Dokument der Rechnung';
      case 'delivery-note_pdf':
        return 'PDF-Dokument des Lieferscheins';
      case 'commercial-invoice_pdf':
        return 'PDF-Dokument der Handelsrechnung';
      case 'packing-list_pdf':
        return 'PDF-Dokument der Packliste';
      default:
        return 'Dokument';
    }
  }

  Future<void> _openDocument(String url) async {
    try {
      final uri = Uri.parse(url);

      if (!await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      )) {
        if (!await launchUrl(
          uri,
          mode: LaunchMode.externalNonBrowserApplication,
        )) {
          await launchUrl(
            uri,
            mode: LaunchMode.inAppWebView,
            webViewConfiguration: const WebViewConfiguration(
              enableJavaScript: true,
              enableDomStorage: true,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        await Clipboard.setData(ClipboardData(text: url));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link wurde in die Zwischenablage kopiert. Sie können ihn in Ihrem Browser einfügen.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _shareDocument(String url, String docType, String orderNumber) async {
    try {
      final documentName = '${_getDocumentTypeName(docType)} - Auftrag $orderNumber';

      await Share.share(
        url,
        subject: documentName,
      );
    } catch (e) {
      if (mounted) {
        await Clipboard.setData(ClipboardData(text: url));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Link kopiert: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _shareOrder(OrderX order) async {
    final String orderInfo = '''
Auftrag ${order.orderNumber}
Datum: ${DateFormat('dd.MM.yyyy').format(order.orderDate)}
Kunde: ${order.customer['company'] ?? order.customer['fullName']}
Betrag: CHF ${(order.calculations['total'] as num? ?? 0).toStringAsFixed(2)}
Status: ${order.status.displayName}
Zahlungsstatus: ${order.paymentStatus.displayName}
''';

    await Share.share(orderInfo, subject: 'Auftrag ${order.orderNumber}');
  }

  Future<void> _releaseOrder(OrderX order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auftrag stornieren'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Möchten Sie den Auftrag ${order.orderNumber} stornieren?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Wichtiger Hinweis:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Alle Produktreservierungen werden aufgehoben\n'
                        '• Die Produkte werden wieder für andere Aufträge verfügbar\n'
                        '• Der Auftrag wird als storniert markiert\n'
                        '• Diese Aktion kann nicht rückgängig gemacht werden',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Stornieren'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        final batch = FirebaseFirestore.instance.batch();

        for (final item in order.items) {
          if (item['is_manual_product'] == true) continue;

          final inventoryRef = FirebaseFirestore.instance
              .collection('inventory')
              .doc(item['product_id']);

          batch.update(inventoryRef, {
            'quantity': FieldValue.increment(item['quantity'] as int),
            'last_modified': FieldValue.serverTimestamp(),
          });

          final stockEntryRef = FirebaseFirestore.instance
              .collection('stock_entries')
              .doc();

          // Create History Entry for cancellation
          final user = FirebaseAuth.instance.currentUser;
          final historyRef = FirebaseFirestore.instance
              .collection('orders')
              .doc(order.id)
              .collection('history')
              .doc();

          batch.set(historyRef, {
            'timestamp': FieldValue.serverTimestamp(),
            'user_id': user?.uid ?? 'unknown',
            'user_email': user?.email ?? 'Unknown User',
            'user_name': user?.displayName ?? user?.email?.split('@')[0] ?? 'Unknown',
            'action': 'order_cancelled',
            'reason': 'Manuell storniert - Reservierungen aufgehoben',
            'changes': {
              'field': 'status',
              'old_value': order.status.name,
              'new_value': OrderStatus.cancelled.name,
              'old_display': order.status.displayName,
              'new_display': OrderStatus.cancelled.displayName,
            },
          });
        }

        final orderRef = FirebaseFirestore.instance
            .collection('orders')
            .doc(order.id);

        batch.update(orderRef, {
          'status': OrderStatus.cancelled.name,
          'cancelled_at': FieldValue.serverTimestamp(),
          'cancellation_reason': 'Manuell storniert - Reservierungen aufgehoben',
        });

        await batch.commit();

        if (mounted) {
          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Auftrag ${order.orderNumber} wurde erfolgreich storniert'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler beim Stornieren des Auftrags: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}