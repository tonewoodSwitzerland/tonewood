import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'quote_model.dart';
import '../services/icon_helper.dart';

// Importiere die View-Status-Definition aus quotes_overview_screen
// (oder definiere sie hier erneut, falls kreuzende Imports problematisch sind)
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
        return const Color(0xFF2196F3);
      case QuoteViewStatus.accepted:
        return const Color(0xFF4CAF50);
      case QuoteViewStatus.rejected:
        return const Color(0xFFF44336);
      case QuoteViewStatus.expired:
        return const Color(0xFF9E9E9E);
    }
  }
}

class QuoteFilterService {
  static const String _filterDocId = 'quote_filter_settings';

  // Filter Model
  static Map<String, dynamic> createEmptyFilter() {
    return {
      'quoteStatus': <String>[],   // Liste von QuoteViewStatus-Namen
      'searchText': '',
      'quickStatus': null,
      // Datumsfilter
      'dateFilterType': null,  // 'current_year', 'current_month', 'custom'
      'startDate': null,
      'endDate': null,
    };
  }

  // Lade gespeicherte Filter
  static Stream<Map<String, dynamic>> loadSavedFilters() {
    return FirebaseFirestore.instance
        .collection('general_data')
        .doc(_filterDocId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return snapshot.data()!;
      }
      return createEmptyFilter();
    });
  }

  // Speichere Filter
  static Future<void> saveFilters(Map<String, dynamic> filters) async {
    await FirebaseFirestore.instance
        .collection('general_data')
        .doc(_filterDocId)
        .set({
      ...filters,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  // Reset Filter
  static Future<void> resetFilters() async {
    await FirebaseFirestore.instance
        .collection('general_data')
        .doc(_filterDocId)
        .delete();
  }

  // Helper: Bestimme den View-Status eines Angebots
  static QuoteViewStatus getViewStatus(Quote quote) {
    if (quote.status == QuoteStatus.accepted) return QuoteViewStatus.accepted;
    if (quote.status == QuoteStatus.rejected) return QuoteViewStatus.rejected;
    if (quote.validUntil.isBefore(DateTime.now())) return QuoteViewStatus.expired;
    return QuoteViewStatus.open;
  }

  // Client-seitige Filter
  static List<Quote> applyClientSideFilters(
      List<Quote> quotes,
      Map<String, dynamic> filters,
      ) {
    var filteredQuotes = quotes;

    // Suchtext Filter
    final searchText = (filters['searchText'] ?? '').toString().toLowerCase();
    if (searchText.isNotEmpty) {
      final searchTerms = searchText.split(' ').where((term) => term.isNotEmpty).toList();

      filteredQuotes = filteredQuotes.where((quote) {
        final company = quote.customer['company']?.toString().toLowerCase() ?? '';
        final fullName = quote.customer['fullName']?.toString().toLowerCase() ?? '';
        final firstName = quote.customer['firstName']?.toString().toLowerCase() ?? '';
        final lastName = quote.customer['lastName']?.toString().toLowerCase() ?? '';

        final searchableContent = [
          quote.quoteNumber.toLowerCase(),
          company,
          fullName,
          firstName,
          lastName,
          '$firstName $lastName',
        ].join(' ');

        return searchTerms.every((term) => searchableContent.contains(term));
      }).toList();
    }

    // Angebotsstatus Filter (QuoteViewStatus)
    final quoteStatusList = List<String>.from(filters['quoteStatus'] ?? []);
    if (quoteStatusList.isNotEmpty) {
      filteredQuotes = filteredQuotes.where((quote) {
        final viewStatus = getViewStatus(quote);
        return quoteStatusList.contains(viewStatus.name);
      }).toList();
    }

    // Quick-Status Filter (für die Schnellfilter-Buttons)
    final quickStatus = filters['quickStatus'] as String?;
    if (quickStatus != null && quickStatus.isNotEmpty) {
      filteredQuotes = filteredQuotes.where((quote) {
        final viewStatus = getViewStatus(quote);
        return viewStatus.name == quickStatus;
      }).toList();
    }

    // Datumsfilter
    final dateFilterType = filters['dateFilterType'] as String?;

    DateTime? startDate;
    DateTime? endDate;

    if (filters['startDate'] != null) {
      if (filters['startDate'] is Timestamp) {
        startDate = (filters['startDate'] as Timestamp).toDate();
      } else if (filters['startDate'] is DateTime) {
        startDate = filters['startDate'] as DateTime;
      }
    }

    if (filters['endDate'] != null) {
      if (filters['endDate'] is Timestamp) {
        endDate = (filters['endDate'] as Timestamp).toDate();
      } else if (filters['endDate'] is DateTime) {
        endDate = filters['endDate'] as DateTime;
      }
    }

    if (dateFilterType != null || startDate != null || endDate != null) {
      filteredQuotes = filteredQuotes.where((quote) {
        final quoteDate = quote.createdAt;

        if (dateFilterType == 'current_year') {
          return quoteDate.year == DateTime.now().year;
        } else if (dateFilterType == 'current_month') {
          final now = DateTime.now();
          return quoteDate.year == now.year && quoteDate.month == now.month;
        }

        if (dateFilterType == 'custom' || startDate != null || endDate != null) {
          if (startDate != null) {
            final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
            if (quoteDate.isBefore(startOfDay)) return false;
          }
          if (endDate != null) {
            final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
            if (quoteDate.isAfter(endOfDay)) return false;
          }
          return true;
        }

        return true;
      }).toList();
    }

    return filteredQuotes;
  }

  // Helper: Prüfe ob Filter aktiv sind
  static bool hasActiveFilters(Map<String, dynamic> filters) {
    return (filters['quoteStatus'] as List?)?.isNotEmpty == true ||
        (filters['searchText'] ?? '').toString().isNotEmpty ||
        filters['quickStatus'] != null ||
        filters['dateFilterType'] != null ||
        filters['startDate'] != null ||
        filters['endDate'] != null;
  }

  // NEU: Filter-Zusammenfassung für Chips
  static String getFilterSummary(Map<String, dynamic> filters) {
    final parts = <String>[];

    // Suchtext
    final searchText = (filters['searchText'] ?? '').toString();
    if (searchText.isNotEmpty) {
      parts.add('Suche: "$searchText"');
    }

    // Quick Status
    final quickStatus = filters['quickStatus'] as String?;
    if (quickStatus != null) {
      try {
        final status = QuoteViewStatus.values.firstWhere((s) => s.name == quickStatus);
        parts.add('Status: ${status.displayName}');
      } catch (_) {}
    }

    // Angebotsstatus (aus erweitertem Filter)
    final quoteStatusList = List<String>.from(filters['quoteStatus'] ?? []);
    if (quoteStatusList.isNotEmpty && quickStatus == null) {
      final statusNames = quoteStatusList.map((statusName) {
        try {
          final status = QuoteViewStatus.values.firstWhere((s) => s.name == statusName);
          return status.displayName;
        } catch (_) {
          return statusName;
        }
      }).join(', ');
      parts.add('Status: $statusNames');
    }

    // Datumsfilter
    final dateFilterType = filters['dateFilterType'] as String?;
    if (dateFilterType == 'current_year') {
      parts.add('Zeitraum: ${DateTime.now().year}');
    } else if (dateFilterType == 'current_month') {
      final monthNames = ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
      parts.add('Zeitraum: ${monthNames[DateTime.now().month - 1]}');
    } else if (dateFilterType == 'custom') {
      DateTime? startDate;
      DateTime? endDate;

      if (filters['startDate'] != null) {
        if (filters['startDate'] is Timestamp) {
          startDate = (filters['startDate'] as Timestamp).toDate();
        } else if (filters['startDate'] is DateTime) {
          startDate = filters['startDate'] as DateTime;
        }
      }

      if (filters['endDate'] != null) {
        if (filters['endDate'] is Timestamp) {
          endDate = (filters['endDate'] as Timestamp).toDate();
        } else if (filters['endDate'] is DateTime) {
          endDate = filters['endDate'] as DateTime;
        }
      }

      if (startDate != null && endDate != null) {
        parts.add('Zeitraum: ${_formatDate(startDate)} - ${_formatDate(endDate)}');
      } else if (startDate != null) {
        parts.add('Ab: ${_formatDate(startDate)}');
      } else if (endDate != null) {
        parts.add('Bis: ${_formatDate(endDate)}');
      }
    }

    return parts.isEmpty ? 'Keine Filter' : parts.join(' • ');
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

// Filter Dialog
class QuoteFilterDialog extends StatefulWidget {
  final Map<String, dynamic> currentFilters;
  final Function(Map<String, dynamic>) onApply;

  const QuoteFilterDialog({
    Key? key,
    required this.currentFilters,
    required this.onApply,
  }) : super(key: key);

  @override
  State<QuoteFilterDialog> createState() => _QuoteFilterDialogState();
}

class _QuoteFilterDialogState extends State<QuoteFilterDialog> {
  late Map<String, dynamic> _filters;

  @override
  void initState() {
    super.initState();
    _filters = Map<String, dynamic>.from(widget.currentFilters);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  getAdaptiveIcon(iconName: 'filter_list', defaultIcon: Icons.filter_list),
                  const SizedBox(width: 10),
                  const Text(
                    'Filter',
                    style: TextStyle(
                      fontSize: 20,
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

            const Divider(height: 1),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Angebotsstatus
                    _buildFilterSection(
                      title: 'Angebotsstatus',
                      icon: Icons.assignment,
                      iconName: 'assignment',
                      child: Column(
                        children: QuoteViewStatus.values.map((status) {
                          final isSelected = (_filters['quoteStatus'] as List).contains(status.name);
                          return CheckboxListTile(
                            dense: true,
                            title: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: status.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(status.displayName),
                              ],
                            ),
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                final statusList = List<String>.from(_filters['quoteStatus'] ?? []);
                                if (value == true) {
                                  statusList.add(status.name);
                                } else {
                                  statusList.remove(status.name);
                                }
                                _filters['quoteStatus'] = statusList;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Datumsfilter
                    _buildFilterSection(
                      title: 'Zeitraum',
                      icon: Icons.calendar_today,
                      iconName: 'calendar_today',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: Text('${DateTime.now().year}'),
                                selected: _filters['dateFilterType'] == 'current_year',
                                onSelected: (selected) {
                                  setState(() {
                                    _filters['dateFilterType'] = selected ? 'current_year' : null;
                                    _filters['startDate'] = null;
                                    _filters['endDate'] = null;
                                  });
                                },
                              ),
                              ChoiceChip(
                                label: Text(_getCurrentMonthName()),
                                selected: _filters['dateFilterType'] == 'current_month',
                                onSelected: (selected) {
                                  setState(() {
                                    _filters['dateFilterType'] = selected ? 'current_month' : null;
                                    _filters['startDate'] = null;
                                    _filters['endDate'] = null;
                                  });
                                },
                              ),
                              ChoiceChip(
                                label: const Text('Benutzerdefiniert'),
                                selected: _filters['dateFilterType'] == 'custom',
                                onSelected: (selected) {
                                  setState(() {
                                    _filters['dateFilterType'] = selected ? 'custom' : null;
                                  });
                                },
                              ),
                            ],
                          ),

                          // Custom Datumsbereich
                          if (_filters['dateFilterType'] == 'custom') ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: getAdaptiveIcon(iconName: 'calendar_today', defaultIcon: Icons.calendar_today),
                                    label: Text(
                                      _filters['startDate'] != null
                                          ? _formatDateDisplay(_getDateTime(_filters['startDate']))
                                          : 'Von',
                                    ),
                                    onPressed: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: _getDateTime(_filters['startDate']) ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                        locale: const Locale('de', 'DE'),
                                      );
                                      if (date != null) {
                                        setState(() {
                                          _filters['startDate'] = date;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: getAdaptiveIcon(iconName: 'calendar_today', defaultIcon: Icons.calendar_today),
                                    label: Text(
                                      _filters['endDate'] != null
                                          ? _formatDateDisplay(_getDateTime(_filters['endDate']))
                                          : 'Bis',
                                    ),
                                    onPressed: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: _getDateTime(_filters['endDate']) ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                        locale: const Locale('de', 'DE'),
                                      );
                                      if (date != null) {
                                        setState(() {
                                          _filters['endDate'] = date;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            if (_filters['startDate'] != null || _filters['endDate'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: TextButton.icon(
                                  icon: getAdaptiveIcon(iconName: 'clear', defaultIcon: Icons.clear),
                                  label: const Text('Datum zurücksetzen'),
                                  onPressed: () {
                                    setState(() {
                                      _filters['startDate'] = null;
                                      _filters['endDate'] = null;
                                    });
                                  },
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    icon: getAdaptiveIcon(iconName: 'clear', defaultIcon: Icons.clear),
                    label: const Text('Zurücksetzen'),
                    onPressed: () {
                      setState(() {
                        _filters = QuoteFilterService.createEmptyFilter();
                      });
                    },
                  ),
                  FilledButton(
                    onPressed: () {
                      widget.onApply(_filters);
                      Navigator.pop(context);
                    },
                    child: const Text('Anwenden'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCurrentMonthName() {
    final monthNames = ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
    return monthNames[DateTime.now().month - 1];
  }

  DateTime? _getDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _formatDateDisplay(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Widget _buildFilterSection({
    required String title,
    required IconData icon,
    required String iconName,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              getAdaptiveIcon(iconName: iconName, defaultIcon: icon, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}