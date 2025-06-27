import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/order_service.dart';
import '../components/quote_model.dart';
// Oben bei den Imports ergänzen:
import '../services/icon_helper.dart';


// Zentrale Farbdefinitionen für Angebote
class QuoteColors {
  static const open = Color(0xFF2196F3);        // Material Blue
  static const accepted = Color(0xFF4CAF50);     // Material Green
  static const rejected = Color(0xFFF44336);     // Material Red
  static const expired = Color(0xFF9E9E9E);      // Material Grey
}

// Vereinfachte Status für die Ansicht
enum QuoteViewStatus {
  open,
  accepted,
  rejected,
  expired,
}

extension QuoteViewStatusExtension on QuoteViewStatus {
  String get displayName {
    switch (this) {
      case QuoteViewStatus.open:
        return 'Offen';
      case QuoteViewStatus.accepted:
        return 'Angenommen';
      case QuoteViewStatus.rejected:
        return 'Abgelehnt';
      case QuoteViewStatus.expired:
        return 'Abgelaufen';
    }
  }

  Color get color {
    switch (this) {
      case QuoteViewStatus.open:
        return QuoteColors.open;
      case QuoteViewStatus.accepted:
        return QuoteColors.accepted;
      case QuoteViewStatus.rejected:
        return QuoteColors.rejected;
      case QuoteViewStatus.expired:
        return QuoteColors.expired;
    }
  }
}

class QuotesOverviewScreen extends StatefulWidget {
  const QuotesOverviewScreen({Key? key}) : super(key: key);

  @override
  State<QuotesOverviewScreen> createState() => _QuotesOverviewScreenState();
}

class _QuotesOverviewScreenState extends State<QuotesOverviewScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  QuoteViewStatus? _filterStatus;
  String _rejectionReason = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Angebote', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          // Filter-Button
          PopupMenuButton<dynamic>(
            icon: Badge(
              isLabelVisible: _filterStatus != null,
              label: const Text('!'),
              child: getAdaptiveIcon(iconName: 'filter_list', defaultIcon: Icons.filter_list),
            ),
            onSelected: (value) {
              if (value == 'clear_all') {
                setState(() {
                  _filterStatus = null;
                });
              } else if (value is QuoteViewStatus?) {
                setState(() {
                  _filterStatus = value;
                });
              }
            },
            itemBuilder: (context) => [
              if (_filterStatus != null)
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
              if (_filterStatus != null)
                const PopupMenuDivider(),
              const PopupMenuItem(
                value: null,
                child: Text('Alle anzeigen'),
              ),
              ...QuoteViewStatus.values.map((status) => PopupMenuItem(
                value: status,
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: status.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(status.displayName),
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
                hintText: 'Suche nach Kunde, Angebotsnummer...',
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

          // Angebotsliste
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildQuotesQuery(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Fehler: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final quotes = snapshot.data!.docs
                    .map((doc) => Quote.fromFirestore(doc))
                    .where((quote) {
                  // Suchfilter
                  if (_searchQuery.isNotEmpty) {
                    final searchLower = _searchQuery.toLowerCase();
                    return quote.quoteNumber.toLowerCase().contains(searchLower) ||
                        quote.customer['company'].toString().toLowerCase().contains(searchLower) ||
                        quote.customer['fullName'].toString().toLowerCase().contains(searchLower);
                  }
                  return true;
                })
                    .where((quote) {
                  // Status-Filter
                  if (_filterStatus == null) return true;

                  final viewStatus = _getViewStatus(quote);
                  return viewStatus == _filterStatus;
                })
                    .toList();

                if (quotes.isEmpty) {
                  return Center(
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
                          'Keine Angebote gefunden',
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
                  itemCount: quotes.length,
                  itemBuilder: (context, index) {
                    final quote = quotes[index];
                    return _buildCompactQuoteCard(quote);
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
      stream: FirebaseFirestore.instance.collection('quotes').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 60);

        final quotes = snapshot.data!.docs
            .map((doc) => Quote.fromFirestore(doc))
            .toList();

        final openQuotes = quotes.where((q) {
          final viewStatus = _getViewStatus(q);
          return viewStatus == QuoteViewStatus.open;
        }).length;

        final expiredQuotes = quotes.where((q) {
          final viewStatus = _getViewStatus(q);
          return viewStatus == QuoteViewStatus.expired;
        }).length;

        return Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _buildCompactStatCard(
                  'Offen',
                  openQuotes.toString(),
                  Icons.schedule,
                  QuoteColors.open,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactStatCard(
                  'Abgelaufen',
                  expiredQuotes.toString(),
                  Icons.timer_off,
                  QuoteColors.expired,
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

  Stream<QuerySnapshot> _buildQuotesQuery() {
    Query query = FirebaseFirestore.instance.collection('quotes');
    return query.orderBy('createdAt', descending: true).snapshots();
  }

  QuoteViewStatus _getViewStatus(Quote quote) {
    final isExpired = quote.validUntil.isBefore(DateTime.now());

    if (quote.status == QuoteStatus.accepted) {
      return QuoteViewStatus.accepted;
    } else if (quote.status == QuoteStatus.rejected) {
      return QuoteViewStatus.rejected;
    } else if (isExpired) {
      return QuoteViewStatus.expired;
    } else {
      return QuoteViewStatus.open;
    }
  }

  Widget _buildCompactQuoteCard(Quote quote) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final viewStatus = _getViewStatus(quote);

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
        onTap: () => _showQuoteDetails(quote),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Erste Zeile: Angebotsnummer, Datum, Status
              Row(
                children: [
                  // Angebotsnummer & Datum
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Angebot ${quote.quoteNumber}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('dd.MM.yy').format(quote.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status-Chip
                  _buildCompactStatusChip(viewStatus),
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
                            quote.customer['company'] ?? quote.customer['fullName'],
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
                      color: QuoteColors.accepted.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'CHF ${quote.calculations['total'].toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: QuoteColors.accepted,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Dritte Zeile: Gültigkeit
              Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 12,
                    color: viewStatus == QuoteViewStatus.expired
                        ? QuoteColors.expired
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Gültig bis ${DateFormat('dd.MM.yy').format(quote.validUntil)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: viewStatus == QuoteViewStatus.expired
                          ? QuoteColors.expired
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Vierte Zeile: Kompakte Aktionen
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (viewStatus == QuoteViewStatus.open) ...[
                    _buildCompactActionButton(
                      icon: Icons.shopping_cart_outlined,
                      onPressed: () => _convertToOrder(quote),
                      tooltip: 'Beauftragen',
                      color: QuoteColors.accepted,
                    ),
                    const SizedBox(width: 4),
                    _buildCompactActionButton(
                      icon: Icons.cancel_outlined,
                      onPressed: () => _rejectQuote(quote),
                      tooltip: 'Ablehnen',
                      color: QuoteColors.rejected,
                    ),
                    const SizedBox(width: 4),
                  ],
                  _buildCompactActionButton(
                    icon: Icons.history,
                    onPressed: () => _showQuoteHistory(quote),
                    tooltip: 'Verlauf',
                  ),
                  const SizedBox(width: 4),
                  _buildCompactActionButton(
                    icon: Icons.picture_as_pdf_outlined,
                    onPressed: () => _viewQuotePdf(quote),
                    tooltip: 'PDF anzeigen',
                  ),
                  const SizedBox(width: 4),
                  _buildCompactActionButton(
                    icon: Icons.share_outlined,
                    onPressed: () => _shareQuote(quote),
                    tooltip: 'Teilen',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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

  Widget _buildCompactStatusChip(QuoteViewStatus status) {
    final color = status.color;

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

  void _showQuoteDetails(Quote quote) {
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
                  getAdaptiveIcon(iconName: 'description', defaultIcon: Icons.description),
                  const SizedBox(width: 10),
                  Text(
                    'Angebot ${quote.quoteNumber}',
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
                    // Angebotsinformationen
                    _buildInfoSection('Angebotsinformationen', [
                      _buildInfoRow('Angebotsnummer:', quote.quoteNumber),
                      _buildInfoRow('Datum:', DateFormat('dd.MM.yyyy HH:mm').format(quote.createdAt)),
                      _buildInfoRow('Status:', _getViewStatus(quote).displayName),
                      _buildInfoRow('Gültig bis:', DateFormat('dd.MM.yyyy').format(quote.validUntil)),
                    ]),

                    const SizedBox(height: 20),

                    // Kundeninformationen
                    _buildInfoSection('Kunde', [
                      _buildInfoRow('Firma:', quote.customer['company'] ?? '-'),
                      _buildInfoRow('Name:', quote.customer['fullName'] ?? '-'),
                      _buildInfoRow('E-Mail:', quote.customer['email'] ?? '-'),
                      _buildInfoRow('Adresse:', '${quote.customer['street']} ${quote.customer['houseNumber']}, ${quote.customer['zipCode']} ${quote.customer['city']}'),
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
                    ...quote.items.map((item) {
                      final quantity = item['quantity'] ?? 0;
                      final pricePerUnit = item['price_per_unit'] ?? 0;
                      final total = item['total'] ?? (quantity * pricePerUnit);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['product_name'] ?? 'Unbekanntes Produkt',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text('Menge: $quantity ${item['unit'] ?? 'Stück'}'),
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
                      _buildInfoRow('Zwischensumme:', 'CHF ${(quote.calculations['subtotal'] ?? 0).toStringAsFixed(2)}'),
                      if ((quote.calculations['item_discounts'] ?? 0) > 0)
                        _buildInfoRow('Positionsrabatte:', 'CHF -${(quote.calculations['item_discounts'] ?? 0).toStringAsFixed(2)}'),
                      if ((quote.calculations['total_discount_amount'] ?? 0) > 0)
                        _buildInfoRow('Gesamtrabatt:', 'CHF -${(quote.calculations['total_discount_amount'] ?? 0).toStringAsFixed(2)}'),
                      _buildInfoRow('Nettobetrag:', 'CHF ${(quote.calculations['net_amount'] ?? 0).toStringAsFixed(2)}'),
                      _buildInfoRow('MwSt:', 'CHF ${(quote.calculations['vat_amount'] ?? 0).toStringAsFixed(2)}'),
                      _buildInfoRow('Gesamtbetrag:', 'CHF ${(quote.calculations['total'] ?? 0).toStringAsFixed(2)}', isTotal: true),
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

  void _showQuoteHistory(Quote quote) {
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
                      'Verlauf - ${quote.quoteNumber}',
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
                    .collection('quotes')
                    .doc(quote.id)
                    .collection('history')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final historyEntries = snapshot.data?.docs ?? [];

                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: historyEntries.length + 1, // +1 für Erstellungs-Eintrag
                    itemBuilder: (context, index) {
                      // Letzter Eintrag ist immer die Erstellung
                      if (index == historyEntries.length) {
                        return _buildHistoryEntry(
                          icon: Icons.add_circle_outline,
                          color: Colors.green,
                          title: 'Angebot erstellt',
                          subtitle: 'Initiale Erstellung des Angebots',
                          timestamp: quote.createdAt,
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
                          color = _getStatusColorFromString(changes['new_value'] ?? '');
                          title = 'Status geändert';
                          subtitle = '${changes['old_display'] ?? 'Unbekannt'} → ${changes['new_display'] ?? 'Unbekannt'}';
                          break;
                        case 'converted_to_order':
                          icon = Icons.shopping_cart;
                          color = QuoteColors.accepted;
                          title = 'In Auftrag umgewandelt';
                          subtitle = 'Auftragsnummer: ${data['order_number'] ?? 'Unbekannt'}';
                          break;
                        case 'pdf_viewed':
                          icon = Icons.picture_as_pdf;
                          color = Colors.blue;
                          title = 'PDF angezeigt';
                          subtitle = 'Angebots-PDF wurde geöffnet';
                          break;
                        case 'shared':
                          icon = Icons.share;
                          color = Colors.purple;
                          title = 'Angebot geteilt';
                          subtitle = 'Angebot wurde weitergeleitet';
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
          // Timeline Icon
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

  Color _getStatusColorFromString(String status) {
    switch (status) {
      case 'accepted':
        return QuoteColors.accepted;
      case 'rejected':
        return QuoteColors.rejected;
      default:
        return QuoteColors.open;
    }
  }

  Future<void> _convertToOrder(Quote quote) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Angebot beauftragen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Möchten Sie das Angebot ${quote.quoteNumber} in einen Auftrag umwandeln?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: QuoteColors.accepted.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: QuoteColors.accepted.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: QuoteColors.accepted, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Was passiert:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Ein neuer Auftrag wird erstellt\n'
                        '• Das Angebot wird als "Angenommen" markiert\n'
                        '• Lagerbestände werden reserviert\n'
                        '• Dokumente müssen im Auftragsmenü erstellt werden!',
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
              backgroundColor: QuoteColors.accepted,
              foregroundColor: Colors.white,
            ),
            child: const Text('Beauftragen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Loading anzeigen
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        // Erstelle Auftrag aus Angebot
        final order = await OrderService.createOrderFromQuote(quote.id);

        // History Entry wird automatisch durch OrderService erstellt
        // Zusätzlicher History Entry für UI
        final user = FirebaseAuth.instance.currentUser;
        await FirebaseFirestore.instance
            .collection('quotes')
            .doc(quote.id)
            .collection('history')
            .add({
          'timestamp': FieldValue.serverTimestamp(),
          'user_id': user?.uid ?? 'unknown',
          'user_email': user?.email ?? 'Unknown User',
          'user_name': user?.displayName ?? user?.email?.split('@')[0] ?? 'Unknown',
          'action': 'converted_to_order',
          'order_number': order.orderNumber,
        });

        if (mounted) {
          Navigator.pop(context); // Loading Dialog schließen

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Angebot ${quote.quoteNumber} wurde erfolgreich beauftragt'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Loading Dialog schließen

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler beim Beauftragen: $e'),
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

  Future<void> _viewQuotePdf(Quote quote) async {
    if (quote.documents['quote_pdf'] == null || quote.documents['quote_pdf']!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kein PDF verfügbar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // History Entry für PDF-Ansicht
    _createHistoryEntry(quote, 'pdf_viewed');

    try {
      final uri = Uri.parse(quote.documents['quote_pdf']!);

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
        await Clipboard.setData(ClipboardData(text: quote.documents['quote_pdf']!));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link wurde in die Zwischenablage kopiert'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _shareQuote(Quote quote) async {
    // History Entry für Teilen
    _createHistoryEntry(quote, 'shared');

    final String quoteInfo = '''
Angebot ${quote.quoteNumber}
Datum: ${DateFormat('dd.MM.yyyy').format(quote.createdAt)}
Kunde: ${quote.customer['company'] ?? quote.customer['fullName']}
Betrag: CHF ${quote.calculations['total'].toStringAsFixed(2)}
Gültig bis: ${DateFormat('dd.MM.yyyy').format(quote.validUntil)}
Status: ${_getViewStatus(quote).displayName}
''';

    await Share.share(quoteInfo, subject: 'Angebot ${quote.quoteNumber}');
  }

  Future<void> _rejectQuote(Quote quote) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Angebot ablehnen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Möchten Sie das Angebot ${quote.quoteNumber} ablehnen?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: QuoteColors.rejected.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: QuoteColors.rejected.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: QuoteColors.rejected, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Was passiert:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Das Angebot wird als "Abgelehnt" markiert\n'
                        '• Eventuelle Reservierungen werden freigegeben\n'
                        '• Das Angebot kann später nicht mehr beauftragt werden',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Grund für Ablehnung (optional)',
                hintText: 'z.B. Preis zu hoch, andere Lösung gefunden...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                // Speichere Grund temporär
                _rejectionReason = value;
              },
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
              backgroundColor: QuoteColors.rejected,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ablehnen'),
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

        final user = FirebaseAuth.instance.currentUser;
        final batch = FirebaseFirestore.instance.batch();

        // Update Quote Status
        final quoteRef = FirebaseFirestore.instance
            .collection('quotes')
            .doc(quote.id);

        batch.update(quoteRef, {
          'status': QuoteStatus.rejected.name,
          'rejected_at': FieldValue.serverTimestamp(),
          'rejection_reason': _rejectionReason ?? '',
        });

        // Create History Entry
        final historyRef = FirebaseFirestore.instance
            .collection('quotes')
            .doc(quote.id)
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
            'old_value': quote.status.name,
            'new_value': QuoteStatus.rejected.name,
            'old_display': quote.status.displayName,
            'new_display': QuoteStatus.rejected.displayName,
          },
          'rejection_reason': _rejectionReason ?? '',
        });

        // Freigabe von Reservierungen (falls vorhanden)
        final reservations = await FirebaseFirestore.instance
            .collection('stock_movements')
            .where('quoteId', isEqualTo: quote.id)
            .where('status', isEqualTo: 'reserved')
            .get();

        for (final doc in reservations.docs) {
          batch.update(doc.reference, {
            'status': 'cancelled',
            'cancelled_at': FieldValue.serverTimestamp(),
            'cancellation_reason': 'Angebot abgelehnt',
          });
        }

        await batch.commit();

        // Reset rejection reason
        _rejectionReason = '';

        if (mounted) {
          Navigator.pop(context); // Loading Dialog schließen

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Angebot ${quote.quoteNumber} wurde abgelehnt'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Loading Dialog schließen

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler beim Ablehnen: $e'),
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

  Future<void> _createHistoryEntry(Quote quote, String action) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance
          .collection('quotes')
          .doc(quote.id)
          .collection('history')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'user_id': user?.uid ?? 'unknown',
        'user_email': user?.email ?? 'Unknown User',
        'user_name': user?.displayName ?? user?.email?.split('@')[0] ?? 'Unknown',
        'action': action,
      });
    } catch (e) {
      // Fehler still behandeln, da es nur History ist
      print('Error creating history entry: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}