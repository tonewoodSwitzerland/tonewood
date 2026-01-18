import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tonewood/home/sales_screen.dart';
import 'package:tonewood/quotes/quote_details_sheet.dart';
import 'package:url_launcher/url_launcher.dart';
import '../orders/order_service.dart';
import 'quote_model.dart';
// Oben bei den Imports ergänzen:
import '../constants.dart';
import '../services/additional_text_manager.dart';
import '../services/icon_helper.dart';
import '../services/pdf_generators/invoice_generator.dart';
import '../services/preview_pdf_viewer_screen.dart';
import '../services/swiss_rounding.dart';


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

double _convertPrice(num priceInCHF, Quote quote) {
  final price = priceInCHF.toDouble();
  final currency = quote.metadata['currency'] ?? 'CHF';
  if (currency == 'CHF') return price;

  final exchangeRates = quote.metadata['exchangeRates'] as Map<String, dynamic>? ?? {};
  final rate = (exchangeRates[currency] as num?)?.toDouble() ?? 1.0;
  return price * rate;
}


class QuotesOverviewScreen extends StatefulWidget {
  const QuotesOverviewScreen({Key? key}) : super(key: key);

  @override
  State<QuotesOverviewScreen> createState() => _QuotesOverviewScreenState();
}

class _QuotesOverviewScreenState extends State<QuotesOverviewScreen> {

  @override
  void initState() {
    super.initState();
    _loadSavedFilterSettings();
  }

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  QuoteViewStatus? _filterStatus;
  String _rejectionReason = '';
  bool _hasUnsearchedChanges = false;


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
              // 1. UI Status aktualisieren
              if (value == 'clear_all') {
                setState(() {
                  _filterStatus = null;
                });
              } else if (value is QuoteViewStatus) {
                setState(() {
                  _filterStatus = value;
                });
              }

              // 2. Einstellung speichern (NEU)
              _saveFilterSettings(value);
            },
            itemBuilder: (context) => [
              if (_filterStatus != null)
                 PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      getAdaptiveIcon(
                          iconName: 'clear',
                          defaultIcon:Icons.clear, size: 20),
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
              PopupMenuItem(
                value: 'cancelled_orders',
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Nachträglich storniert'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Suchleiste
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child:  StatefulBuilder(
        builder: (context, setSearchState) {
      return TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Suche nach Kunde, Angebotsnummer...',
          hintStyle: const TextStyle(fontSize: 14),
          prefixIcon: getAdaptiveIcon(iconName: 'search', defaultIcon: Icons.search),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: getAdaptiveIcon(iconName: 'clear', defaultIcon: Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setSearchState(() {}); // Nur Suchfeld updaten
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                ),
              IconButton(
                icon: getAdaptiveIcon(
                  iconName: 'search',
                  defaultIcon: Icons.search,
                  color: _searchController.text.toLowerCase() != _searchQuery
                      ? Colors.orange
                      : Theme.of(context).colorScheme.primary,
                ),
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  setState(() {
                    _searchQuery = _searchController.text.toLowerCase();
                  });
                },
              ),
            ],
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) {
          setSearchState(() {}); // Nur Suchfeld-UI updaten, nicht die ganze Liste
        },
      );
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
                  // Suchfilter - NUR wenn _searchQuery gesetzt ist (nach Button-Klick)
                  if (_searchQuery.isNotEmpty) {
                    final searchLower = _searchQuery; // Bereits lowercase
                    final company = quote.customer['company']?.toString().toLowerCase() ?? '';
                    final fullName = quote.customer['fullName']?.toString().toLowerCase() ?? '';
                    final firstName = quote.customer['firstName']?.toString().toLowerCase() ?? '';
                    final lastName = quote.customer['lastName']?.toString().toLowerCase() ?? '';

                    return quote.quoteNumber.toLowerCase().contains(searchLower) ||
                        company.contains(searchLower) ||
                        fullName.contains(searchLower) ||
                        firstName.contains(searchLower) ||
                        lastName.contains(searchLower) ||
                        '$firstName $lastName'.contains(searchLower);
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
                        getAdaptiveIcon(
                          iconName: 'description',
                          defaultIcon:
                          Icons.description,
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

  // -- NEU: Funktion zum Laden aus Firestore --
  Future<void> _loadSavedFilterSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Wir speichern die Einstellungen unter users/{uid}/settings/quotes_overview
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('quotes_overview')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final savedStatusName = data['filter_status'] as String?;

        if (savedStatusName != null) {
          // Versuche, den String (z.B. 'open') zurück in das Enum zu wandeln
          try {
            final status = QuoteViewStatus.values.firstWhere(
                  (e) => e.name == savedStatusName,
            );
            setState(() {
              _filterStatus = status;
            });
          } catch (e) {
            // Falls der gespeicherte Status ungültig ist, passiert nichts (bleibt null/alle)
          }
        } else {
          // Wenn explizit null gespeichert war (für "Alle anzeigen")
          setState(() {
            _filterStatus = null;
          });
        }
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Filtereinstellungen: $e');
    }
  }

  // -- NEU: Funktion zum Speichern in Firestore --
  Future<void> _saveFilterSettings(QuoteViewStatus? status) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('quotes_overview')
          .set({
        // Speichert den internen Namen (z.B. 'accepted') oder null
        'filter_status': status?.name,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Fehler beim Speichern der Filtereinstellungen: $e');
    }
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
                  'schedule',
                  QuoteColors.open,
                  QuoteViewStatus.open, // Ziel-Status für Filter
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactStatCard(
                  'Abgelaufen',
                  expiredQuotes.toString(),
                  Icons.timer_off,
                  'timer_off',
                  QuoteColors.expired,
                  QuoteViewStatus.expired, // Ziel-Status für Filter
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactStatCard(String title, String value, IconData icon, String iconName, Color color, QuoteViewStatus targetStatus) {
    final bool isActive = _filterStatus == targetStatus;

    return GestureDetector(
      onTap: () {
        setState(() {
          // Wenn bereits aktiv, Filter aufheben, sonst setzen
          final newStatus = isActive ? null : targetStatus;
          setState(() {
            _filterStatus = newStatus;
          });

          // NEU: Sofort speichern
          _saveFilterSettings(newStatus);

        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          // Hintergrund wird kräftiger, wenn der Filter aktiv ist
          color: isActive ? color.withOpacity(0.2) : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? color : color.withOpacity(0.2),
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            getAdaptiveIcon(iconName: iconName, defaultIcon: icon, color: color, size: 20),
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
                      fontWeight: FontWeight.bold,
                      color: color,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      color: color.withOpacity(0.8),
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              getAdaptiveIcon(iconName: 'check_circle', defaultIcon: Icons.check_circle, color: color, size: 14),
          ],
        ),
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
                  if (quote.isOrderCancelled && quote.status == QuoteStatus.accepted) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          getAdaptiveIcon(
                            iconName: 'cancel',
                            defaultIcon: Icons.cancel,
                            size: 10,
                            color: Colors.red[700],
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Storniert',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.red[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

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
                        getAdaptiveIcon(
                            iconName: 'business',
                            defaultIcon:
                            Icons.business,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            ( quote.customer['company']?.toString().trim().isNotEmpty == true)
                                ?  quote.customer['company']
                                : ( quote.customer['firstName']?.toString().trim().isNotEmpty == true ||
                                quote.customer['lastName']?.toString().trim().isNotEmpty == true)
                                ? '${quote.customer['firstName'] ?? ''} ${ quote.customer['lastName'] ?? ''}'.trim()
                                :  quote.customer['fullName']?.toString().trim().isNotEmpty == true
                                ?  quote.customer['fullName']
                                : 'Unbekannter Kunde',
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
                      '${quote.metadata['currency']} ${_convertPrice((quote.calculations['total'] as num).toDouble(), quote).toStringAsFixed(2)}',
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
                  getAdaptiveIcon(
                    iconName: 'timer',
                    defaultIcon:
                    Icons.timer,
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

                    _buildCompactActionButton(
                      icon: Icons.content_copy,
                      iconName:'content_copy',
                      onPressed: () =>  _copyQuoteToNewQuote(quote),
                      tooltip: 'Kopieren',
                      color: goldenColour,
                    ),
                    const SizedBox(width: 4),
                    _buildCompactActionButton(
                      icon: Icons.edit,
                      iconName: 'edit',
                      onPressed: () => _editQuote(quote),
                      tooltip: 'Bearbeiten',
                      color: goldenColour
                    ),
                    const SizedBox(width: 4),
                    _buildCompactActionButton(
                      icon: Icons.shopping_cart,
                      iconName:'shopping_cart',
                      onPressed: () => _convertToOrder(quote),
                      tooltip: 'Beauftragen',
                      color: QuoteColors.accepted,
                    ),
                    const SizedBox(width: 4),
                    _buildCompactActionButton(
                      icon: Icons.cancel,
                      iconName:'cancel',
                      onPressed: () => _rejectQuote(quote),
                      tooltip: 'Ablehnen',
                      color: QuoteColors.rejected,
                    ),
                    const SizedBox(width: 4),
                  _buildCompactActionButton(
                    icon: Icons.history,
                    iconName:'history',
                    onPressed: () => _showQuoteHistory(quote),
                    tooltip: 'Verlauf',
                  ),
                  const SizedBox(width: 4),
                  _buildCompactActionButton(
                    icon: Icons.picture_as_pdf,
                    iconName:'picture_as_pdf',
                    onPressed: () => _viewQuotePdf(quote),
                    tooltip: 'PDF anzeigen',
                  ),
                  const SizedBox(width: 4),
                  _buildCompactActionButton(
                    icon: Icons.share,
                    iconName:'share',

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
    required String iconName,
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
            child:  getAdaptiveIcon(
              iconName: iconName,
              defaultIcon:
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
    QuoteDetailsSheet.show(
      context,
      quote: quote,
      onConvertToOrder: _convertToOrder,
      onReject: _rejectQuote,
      onEdit: _editQuote,
      onCopy: _copyQuoteToNewQuote,
      onViewPdf: _viewQuotePdf,
      onShare: _shareQuote,
      onShowHistory: _showQuoteHistory,
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
                  getAdaptiveIcon(
                      iconName: 'history',
                      defaultIcon:Icons.history),
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
                    icon:  getAdaptiveIcon(
                        iconName: 'close',
                        defaultIcon:Icons.close),
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
                          icon: Icons.add_circle,
                          iconName:'add_circle',
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
                      String iconName;
                      Color color;
                      String title;
                      String subtitle;

                      switch (action) {
                        case 'order_cancelled':
                          icon = Icons.cancel;
                          iconName = 'cancel';
                          color = Colors.red;
                          title = 'Auftrag storniert';
                          subtitle = 'Auftragsnummer: ${data['order_number'] ?? 'Unbekannt'}';
                          break;
                        case 'status_change':
                          icon = Icons.swap_horiz;
                          iconName='swap_horiz';
                          color = _getStatusColorFromString(changes['new_value'] ?? '');
                          title = 'Status geändert';
                          subtitle = '${changes['old_display'] ?? 'Unbekannt'} → ${changes['new_display'] ?? 'Unbekannt'}';
                          break;
                        case 'converted_to_order':
                          icon = Icons.shopping_cart;
                          iconName='shopping_cart';
                          color = QuoteColors.accepted;
                          title = 'In Auftrag umgewandelt';
                          subtitle = 'Auftragsnummer: ${data['order_number'] ?? 'Unbekannt'}';
                          break;
                        case 'pdf_viewed':
                          icon = Icons.picture_as_pdf;
                          iconName='picture_as_pdf';
                          color = Colors.blue;
                          title = 'PDF angezeigt';
                          subtitle = 'Angebots-PDF wurde geöffnet';
                          break;
                        case 'shared':
                          icon = Icons.share;
                          iconName='share';
                          color = Colors.purple;
                          title = 'Angebot geteilt';
                          subtitle = 'Angebot wurde weitergeleitet';
                          break;
                        default:
                          icon = Icons.info;
                          iconName='info';

                          color = Colors.grey;
                          title = 'Änderung';
                          subtitle = action;
                      }

                      return _buildHistoryEntry(
                        icon: icon,
                        iconName: iconName,
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
    required String iconName,
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
            child: getAdaptiveIcon(
                iconName: iconName,
                defaultIcon:icon, color: color, size: 20),
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
                    getAdaptiveIcon(
                      iconName: 'person',
                      defaultIcon:
                      Icons.person,
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
    // Zeige zuerst das Konfigurationsdialog
    final configResult = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OrderConfigurationSheet(quote: quote),
    );

    // Wenn abgebrochen wurde
    if (configResult == null) return;

    // Bestätigungs-Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Angebot beauftragen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Möchtest du das Angebot ${quote.quoteNumber} in einen Auftrag umwandeln?'),
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
                      getAdaptiveIcon(
                          iconName: 'info',
                          defaultIcon:Icons.info, color: QuoteColors.accepted, size: 20),
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
                        '• Die Rechnung wird mit Ihren Einstellungen erstellt',
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

        // Erstelle Auftrag aus Angebot MIT den Konfigurationen
        final order = await OrderService.createOrderFromQuoteWithConfig(
          quote.id,
          configResult['additionalTexts'] as Map<String, dynamic>,
          configResult['invoiceSettings'] as Map<String, dynamic>,
        );



        // History Entry wird automatisch durch OrderService erstellt
        final user = FirebaseAuth.instance.currentUser;
        await FirebaseFirestore.instance
            .collection('quotes')
            .doc(quote.id)
            .collection('history')
            .add({
          'timestamp': FieldValue.serverTimestamp(),
          'user_id': user?.uid ?? 'unknown',
          'user_email': user?.email ?? 'Unknown User',
          'user_name': user?.email ?? 'Unknown',
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
            Text('Möchtest du das Angebot ${quote.quoteNumber} ablehnen?'),
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
                      getAdaptiveIcon(
                          iconName: 'warning',
                          defaultIcon:Icons.warning, color: QuoteColors.rejected, size: 20),
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
          'user_name': user?.email ?? 'Unknown',
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

  Future<void> _copyQuoteToNewQuote(Quote quote) async {
    // NEU: Prüfe zuerst ob Online-Shop-Items noch verfügbar sind
    final unavailableItems = <String>[];

    for (final item in quote.items) {
      if (item['is_online_shop_item'] == true && item['online_shop_barcode'] != null) {
        final onlineShopBarcode = item['online_shop_barcode'] as String;

        // Prüfe ob das Produkt noch existiert und nicht verkauft ist
        final shopDoc = await FirebaseFirestore.instance
            .collection('onlineshop')
            .doc(onlineShopBarcode)
            .get();

        if (!shopDoc.exists || shopDoc.data()?['sold'] == true) {
          unavailableItems.add('${item['product_name']} (verkauft/entfernt)');
          continue;
        }

        // Prüfe ob im Warenkorb
        if (shopDoc.data()?['in_cart'] == true) {
          unavailableItems.add('${item['product_name']} (im Warenkorb)');
          continue;
        }

        // Prüfe ob bereits in einem anderen Angebot reserviert
        final reservationCheck = await FirebaseFirestore.instance
            .collection('stock_movements')
            .where('onlineShopBarcode', isEqualTo: onlineShopBarcode)
            .where('type', isEqualTo: 'reservation')
            .where('status', isEqualTo: 'reserved')
            .limit(1)
            .get();

        if (reservationCheck.docs.isNotEmpty) {
          final reservedQuoteId = reservationCheck.docs.first.data()['quoteId'] ?? 'unbekannt';
          unavailableItems.add('${item['product_name']} (reserviert in $reservedQuoteId)');
        }
      }
    }

    // Wenn es nicht verfügbare Items gibt, zeige Warnung
    if (unavailableItems.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              getAdaptiveIcon(
                iconName: 'warning',
                defaultIcon: Icons.warning,
                color: Colors.orange,
              ),
              const SizedBox(width: 8),
              const Text('Nicht verfügbare Artikel'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Folgende Online-Shop-Artikel können nicht kopiert werden:'),
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
                  children: unavailableItems.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        getAdaptiveIcon(
                          iconName: 'cancel',
                          defaultIcon: Icons.cancel,
                          color: Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item, style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Diese Artikel werden beim Kopieren übersprungen. Möchtest du trotzdem fortfahren?',
                style: TextStyle(fontSize: 12),
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
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Trotzdem kopieren'),
            ),
          ],
        ),
      );

      if (proceed != true) return;
    }

    // Bestätigungsdialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Angebot kopieren'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Möchtest du das Angebot ${quote.quoteNumber} als Vorlage für ein neues Angebot verwenden?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      getAdaptiveIcon(
                          iconName: 'info',
                          defaultIcon: Icons.info,
                          color: Colors.blue,
                          size: 20
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Was wird übernommen:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Kunde und Kontaktdaten\n'
                        '• Kostenstelle\n'
                        '• Währung und Steuereinstellungen\n'
                        '• Artikel (wenn noch verfügbar)\n'
                        '• Zusatztexte und Dokumentensprache',
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
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: getAdaptiveIcon(iconName: 'content_copy', defaultIcon: Icons.content_copy),
            label: const Text('Kopieren'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Loading anzeigen
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // NEU: Filtere nicht verfügbare Online-Shop-Items heraus
      final availableItems = quote.items.where((item) {
        if (item['is_online_shop_item'] == true && item['online_shop_barcode'] != null) {
          final productName = item['product_name'] ?? '';
          // Prüfe ob dieses Item in der unavailableItems Liste ist
          return !unavailableItems.any((unavailable) => unavailable.startsWith(productName));
        }
        return true; // Normale Items immer übernehmen
      }).toList();

      // Sammle die Daten
      final quoteData = {
        'customer': quote.customer,
        'costCenter': quote.costCenter,
        'items': availableItems, // NEU: Nur verfügbare Items
        'currency': quote.metadata['currency'] ?? 'CHF',
        'exchangeRates': quote.metadata['exchangeRates'] ?? {
          'CHF': 1.0,
          'EUR': 0.96,
          'USD': 1.08,
        },
        'vatRate': quote.metadata['vatRate'] ?? 8.1,
        'taxOption': quote.metadata['taxOption'] ?? 0,
        'additionalTexts': quote.metadata['additionalTexts'] ?? {},
        'documentLanguage': quote.customer['language'] ?? 'DE',
        'shippingCosts': quote.metadata['shippingCosts'],
      };

      // Modal schließen
      Navigator.pop(context); // Loading Dialog
      Navigator.pop(context); // Quote Details Modal

      // Navigiere zum Sales Screen mit den Daten
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SalesScreen(
            quoteToCopy: quoteData,
          ),
        ),
      );

    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Loading Dialog schließen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Kopieren: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
        'user_name': user?.email ?? 'Unknown',
        'action': action,
      });
    } catch (e) {
      // Fehler still behandeln, da es nur History ist
      print('Error creating history entry: $e');
    }
  }
  Future<void> _editQuote(Quote quote) async {
    // Prüfe ob das Angebot noch bearbeitbar ist
    if (quote.status != QuoteStatus.draft && quote.status != QuoteStatus.sent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nur offene Angebote können bearbeitet werden'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Bestätigungsdialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Angebot bearbeiten'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Möchtest du das Angebot ${quote.quoteNumber} bearbeiten?'),
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
                      getAdaptiveIcon(
                          iconName: 'warning',
                          defaultIcon: Icons.warning,
                          color: Colors.orange,
                          size: 20
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Hinweis:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Alle Änderungen überschreiben das bestehende Angebot\n'
                        '• Das PDF wird neu generiert\n'
                        '• Die Angebotsnummer bleibt erhalten',
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
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: getAdaptiveIcon(iconName: 'edit', defaultIcon: Icons.edit),
            label: const Text('Bearbeiten'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Loading anzeigen
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Sammle die Daten für die Bearbeitung
      final quoteData = {
        'quoteId': quote.id,  // NEU: Quote ID für Update
        'quoteNumber': quote.quoteNumber,  // NEU: Quote Nummer beibehalten
        'customer': quote.customer,
        'costCenter': quote.costCenter,
        'items': quote.items,
        'currency': quote.metadata['currency'] ?? 'CHF',
        'exchangeRates': quote.metadata['exchangeRates'] ?? {
          'CHF': 1.0,
          'EUR': 0.96,
          'USD': 1.08,
        },
        'vatRate': quote.metadata['vatRate'] ?? 8.1,
        'taxOption': quote.metadata['taxOption'] ?? 0,
        'additionalTexts': quote.metadata['additionalTexts'] ?? {},
        'documentLanguage': quote.customer['language'] ?? 'DE',
        'shippingCosts': quote.metadata['shippingCosts'],
      };

      // Modal schließen
      Navigator.pop(context); // Loading Dialog
      Navigator.pop(context); // Quote Details Modal falls offen

      // Navigiere zum Sales Screen im Edit-Modus
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SalesScreen(
            quoteToEdit: quoteData,  // NEU: Andere Property für Edit
          ),
        ),
      );

    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Loading Dialog schließen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Laden: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _OrderConfigurationSheet extends StatefulWidget {
  final Quote quote;

  const _OrderConfigurationSheet({required this.quote});

  @override
  State<_OrderConfigurationSheet> createState() => _OrderConfigurationSheetState();
}

class _OrderConfigurationSheetState extends State<_OrderConfigurationSheet> {
  final ValueNotifier<bool> _additionalTextsSelectedNotifier = ValueNotifier<bool>(false);


  Map<String, dynamic> _invoiceSettings = {
    'invoice_date': DateTime.now(),
    'down_payment_amount': 0.0,
    'down_payment_reference': '',
    'down_payment_date': null,
    'show_dimensions': false,
    // NEU:
    'is_full_payment': false,
    'payment_method': 'BAR',
    'custom_payment_method': '',
    'payment_term_days': 30,
  };

  final _downPaymentController = TextEditingController();
  final _referenceController = TextEditingController();
  final _customPaymentController = TextEditingController(); // NEU
  DateTime? _downPaymentDate;
  DateTime? _invoiceDate = DateTime.now();
  @override
  void initState() {
    super.initState();
    _checkAdditionalTexts();

  }

  Future<void> _checkAdditionalTexts() async {
    final hasTexts = await AdditionalTextsManager.hasTextsSelected();
    _additionalTextsSelectedNotifier.value = hasTexts;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                  getAdaptiveIcon(iconName: 'settings', defaultIcon:
                    Icons.settings,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auftragseinstellungen',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'Angebot ${widget.quote.quoteNumber}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: getAdaptiveIcon(iconName: 'close', defaultIcon:Icons.close),
                ),
              ],
            ),
          ),

          const Divider(),

          // Content


          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        getAdaptiveIcon(iconName: 'info', defaultIcon:
                          Icons.info,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Alle weiteren Dokumente werden im Auftragsbereich erstellt',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),),
                  // Zusatztexte Section mit bestehender Logik
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () {
                          showAdditionalTextsBottomSheet(
                            context,
                            textsSelectedNotifier: _additionalTextsSelectedNotifier,
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              getAdaptiveIcon(iconName: 'text_fields', defaultIcon:
                                Icons.text_fields,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Zusatztexte konfigurieren',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    ValueListenableBuilder<bool>(
                                      valueListenable: _additionalTextsSelectedNotifier,
                                      builder: (context, hasTexts, child) {
                                        return Text(
                                          hasTexts
                                              ? 'Zusatztexte ausgewählt'
                                              : 'Keine Zusatztexte ausgewählt',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: hasTexts
                                                ? Colors.green[700]
                                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              getAdaptiveIcon(iconName:'arrow_forward', defaultIcon:
                                Icons.arrow_forward,
                                size: 16,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

// NEU: Rechnungsdatum auswählen
                  InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _invoiceDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        locale: const Locale('de', 'DE'),
                      );
                      if (picked != null) {
                        setState(() {
                          _invoiceDate = picked;
                          _invoiceSettings['invoice_date'] = picked;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          getAdaptiveIcon(
                            iconName: 'calendar_today',
                            defaultIcon: Icons.calendar_today,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rechnungsdatum',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  _invoiceDate != null
                                      ? DateFormat('dd.MM.yyyy').format(_invoiceDate!)
                                      : DateFormat('dd.MM.yyyy').format(DateTime.now()),
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // NEU: Toggle zwischen Anzahlung und 100% Vorkasse
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {

                                _invoiceSettings['is_full_payment'] = false;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !_invoiceSettings['is_full_payment']
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Anzahlung',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: !_invoiceSettings['is_full_payment']
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.onSurface,
                                  fontWeight: !_invoiceSettings['is_full_payment'] ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _invoiceSettings['is_full_payment'] = true;

                                // Bei 100% Vorkasse: Setze Gesamtbetrag
                                final total = _convertPrice(widget.quote.calculations['total'], widget.quote);
                                _invoiceSettings['down_payment_amount'] = total;
                                _downPaymentController.text = total.toStringAsFixed(2);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _invoiceSettings['is_full_payment']
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '100% Vorauskasse',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _invoiceSettings['is_full_payment']
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.onSurface,
                                  fontWeight: _invoiceSettings['is_full_payment'] ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Gesamtbetrag anzeigen
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Bruttobetrag',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Text(
                          '${widget.quote.metadata['currency']} ${_convertPrice(widget.quote.calculations['total'], widget.quote).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Bedingte Anzeige je nach Zahlungsart
                  if (_invoiceSettings['is_full_payment']) ...[
                    // 100% Vorkasse Optionen
                    Text(
                      'Zahlungsmethode',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('BAR'),
                            value: 'BAR',
                            groupValue: _invoiceSettings['payment_method'],
                            onChanged: (value) {
                              setState(() {

                                _invoiceSettings['payment_method'] = value;
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Andere'),
                            value: 'custom',
                            groupValue: _invoiceSettings['payment_method'],
                            onChanged: (value) {
                              setState(() {

                                _invoiceSettings['payment_method'] = value;
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),

                    if (_invoiceSettings['payment_method'] == 'custom') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _customPaymentController,
                        decoration: InputDecoration(
                          labelText: 'Zahlungsmethode (z.B. PayPal, Karte)',
                          prefixIcon: getAdaptiveIcon(
                            iconName: 'payment',
                            defaultIcon: Icons.payment,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (value) {
                          _invoiceSettings['custom_payment_method'] = value;
                        },
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Vorschau bei 100% Vorkasse
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Bruttobetrag:'),
                              Text('${widget.quote.metadata['currency']} ${_convertPrice(widget.quote.calculations['total'], widget.quote).toStringAsFixed(2)}'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Bezahlt per ${_invoiceSettings['payment_method'] == 'BAR' ? 'BAR' : _customPaymentController.text}:'),
                              Text(
                                '- ${widget.quote.metadata['currency']} ${_convertPrice(widget.quote.calculations['total'], widget.quote).toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.green),
                              ),
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Restbetrag:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${widget.quote.metadata['currency']} 0.00',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  ] else ...[
                    // Anzahlung Felder
                    TextField(
                      controller: _downPaymentController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Anzahlung BRUTTO (${widget.quote.metadata['currency']})',
                        prefixIcon: getAdaptiveIcon(
                          iconName: 'payments',
                          defaultIcon: Icons.payments,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        helperText: 'Betrag der bereits geleisteten Anzahlung',
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _invoiceSettings['down_payment_amount'] = double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    // Rest wie bisher (Belegnummer, Datum, etc.)
                    TextField(
                      controller: _referenceController,
                      decoration: InputDecoration(
                        labelText: 'Belegnummer / Notiz',
                        prefixIcon: getAdaptiveIcon(iconName: 'description', defaultIcon: Icons.description),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        helperText: 'z.B. Anzahlung AR-2025-0004 vom 15.05.2025',
                      ),
                      onChanged: (value) {
                        _invoiceSettings['down_payment_reference'] = value;
                      },
                    ),

                    const SizedBox(height: 16),

// NEU: Datum der Anzahlung
                    InkWell(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _downPaymentDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          locale: const Locale('de', 'DE'),
                        );
                        if (picked != null) {
                          setState(() {
                            _downPaymentDate = picked;
                            _invoiceSettings['down_payment_date'] = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            getAdaptiveIcon(
                              iconName: 'calendar_today',
                              defaultIcon: Icons.calendar_today,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Datum der Anzahlung',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    _downPaymentDate != null
                                        ? DateFormat('dd.MM.yyyy').format(_downPaymentDate!)
                                        : 'Datum auswählen',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                            if (_downPaymentDate != null)
                              IconButton(
                                icon: getAdaptiveIcon(
                                  iconName: 'clear',
                                  defaultIcon: Icons.clear,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _downPaymentDate = null;
                                    _invoiceSettings['down_payment_date'] = null;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // NEU: Zahlungsziel (nur wenn nicht 100% Vorkasse)
                  if (!_invoiceSettings['is_full_payment']) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Zahlungsziel',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),

                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          RadioListTile<int>(
                            title: const Text('10 Tage'),
                            value: 10,
                            groupValue: _invoiceSettings['payment_term_days'],
                            onChanged: (value) {
                              setState(() {
                                _invoiceSettings['payment_term_days'] = value;
                              });
                            },
                          ),
                          RadioListTile<int>(
                            title: const Text('14 Tage'),
                            value: 14,
                            groupValue: _invoiceSettings['payment_term_days'],
                            onChanged: (value) {
                              setState(() {

                                _invoiceSettings['payment_term_days'] = value;
                              });
                            },
                          ),
                          RadioListTile<int>(
                            title: const Text('30 Tage'),
                            value: 30,
                            groupValue: _invoiceSettings['payment_term_days'],
                            onChanged: (value) {
                              setState(() {

                                _invoiceSettings['payment_term_days'] = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],



                  // Vorschau der Anzahlung
                  if (_invoiceSettings['down_payment_amount'] > 0) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Bruttobetrag:'),
                              Text('${widget.quote.metadata['currency']} ${_convertPrice(widget.quote.calculations['total'], widget.quote).toStringAsFixed(2)}'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Anzahlung:'),
                              Text(
                                '- ${widget.quote.metadata['currency']} ${_invoiceSettings['down_payment_amount'].toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Restbetrag:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${widget.quote.metadata['currency']} ${(_convertPrice(widget.quote.calculations['total'], widget.quote) - _invoiceSettings['down_payment_amount']).toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // NEU: Vorschau-Button
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (dialogContext) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );

                    final additionalTexts = await AdditionalTextsManager.loadAdditionalTexts();
                    print('✓ additionalTexts geladen');

                    final previewInvoiceSettings = {
                      'invoice_date': _invoiceDate,
                      'down_payment_amount': double.tryParse(_downPaymentController.text) ?? 0.0,
                      'down_payment_reference': _referenceController.text,
                      'down_payment_date': _downPaymentDate,
                      'show_dimensions': _invoiceSettings['show_dimensions'] ?? false,
                      // NEU: Die neuen Felder hinzufügen
                      'is_full_payment': _invoiceSettings['is_full_payment'] ?? false,
                      'payment_method': _invoiceSettings['payment_method'] ?? 'BAR',
                      'custom_payment_method': _invoiceSettings['custom_payment_method'] ?? '',
                      'payment_term_days': _invoiceSettings['payment_term_days'] ?? 30,
                    };
                    print('✓ previewInvoiceSettings erstellt');

                    final rawExchangeRates = widget.quote.metadata['exchangeRates'] as Map<String, dynamic>? ?? {};
                    final exchangeRates = <String, double>{
                      'CHF': 1.0,
                    };
                    rawExchangeRates.forEach((key, value) {
                      if (value != null) {
                        exchangeRates[key] = (value as num).toDouble();
                      }
                    });
                    print('✓ exchangeRates konvertiert');

                    // Sichere Konvertierung aller numerischen Werte
                    final safeCalculations = <String, dynamic>{};
                    widget.quote.calculations.forEach((key, value) {
                      if (value is num) {
                        safeCalculations[key] = value.toDouble();
                      } else {
                        safeCalculations[key] = value;
                      }
                    });
                    print('✓ safeCalculations konvertiert');

                    print('→ Rufe InvoiceGenerator.generateInvoicePdf auf...');
                    print(_invoiceSettings);
                    print(previewInvoiceSettings);
                    final roundingSettings = await SwissRounding.loadRoundingSettings();

                    final pdfBytes = await InvoiceGenerator.generateInvoicePdf(
                      items: widget.quote.items,
                      customerData: widget.quote.customer,
                      fairData: widget.quote.fair,
                      costCenterCode: widget.quote.costCenter?['code'] ?? '00000',
                      currency: widget.quote.metadata['currency'] ?? 'CHF',
                      exchangeRates: exchangeRates,
                      language: widget.quote.customer['language'] ?? 'DE',
                      invoiceNumber: 'PREVIEW',
                      quoteNumber: widget.quote.quoteNumber,
                      shippingCosts: widget.quote.metadata['shippingCosts'] as Map<String, dynamic>?,
                      calculations: safeCalculations,
                      paymentTermDays: _invoiceSettings['payment_term_days'] ?? 30, // NEU: Aus Settings
                      taxOption: widget.quote.metadata['taxOption'] ?? 0,
                      vatRate: (widget.quote.metadata['vatRate'] as num?)?.toDouble() ?? 8.1,
                      downPaymentSettings: previewInvoiceSettings,
                      additionalTexts: additionalTexts,
                      roundingSettings: roundingSettings
                    );

                    print('✓ PDF erfolgreich generiert');

                    if (mounted) {
                      Navigator.pop(context);

                      await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (bottomSheetContext) => Container(
                          height: MediaQuery.of(context).size.height * 0.95,
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 40,
                                height: 4,
                                margin: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                child: Row(
                                  children: [
                                    getAdaptiveIcon(iconName: 'picture_as_pdf', defaultIcon:
                                      Icons.picture_as_pdf,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Rechnung Vorschau',
                                        style: Theme.of(context).textTheme.titleLarge,
                                      ),
                                    ),
                                    IconButton(
                                      icon: getAdaptiveIcon(iconName: 'close', defaultIcon:Icons.close),
                                      onPressed: () => Navigator.pop(bottomSheetContext),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(),
                              Expanded(
                                child: PreviewPDFViewerScreen(
                                  pdfBytes: pdfBytes,
                                  title: 'Rechnung Vorschau',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  } catch (e, stackTrace) {
                    print('Fehler bei der Vorschau:');
                    print('Error: $e');
                    print('StackTrace:\n$stackTrace');

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Fehler: $e'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.all(8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    }
                  }
                },
                icon: getAdaptiveIcon(iconName: 'visibility',defaultIcon:Icons.visibility),
                label: const Text('Rechnung Vorschau'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Actions
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Abbrechen'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      // Aktualisiere die Settings vor dem Zurückgeben
                      _invoiceSettings['invoice_date'] = _invoiceDate; // NEU
                      _invoiceSettings['down_payment_date'] = _downPaymentDate; // NEU
                      _invoiceSettings['down_payment_amount'] = double.tryParse(_downPaymentController.text) ?? 0.0;
                      _invoiceSettings['down_payment_reference'] = _referenceController.text;


                      // Lade die aktuellen Zusatztexte
                      final additionalTexts = await AdditionalTextsManager.loadAdditionalTexts();

                      Navigator.pop(context, {
                        'additionalTexts': additionalTexts,
                        'invoiceSettings': _invoiceSettings,
                      });
                    },
                    child: const Text('Weiter'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  @override
  void dispose() {
    _downPaymentController.dispose();
    _referenceController.dispose();
    _customPaymentController.dispose();
    _additionalTextsSelectedNotifier.dispose();
    super.dispose();
  }

}