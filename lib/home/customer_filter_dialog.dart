import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'customer_filter_service.dart';
import '../services/icon_helper.dart';

class CustomerFilterDialog {
  static void show(
      BuildContext context, {
        required Map<String, dynamic> currentFilters,
        required Function(Map<String, dynamic>) onApply,
      }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CustomerFilterBottomSheet(
        currentFilters: currentFilters,
        onApply: onApply,
      ),
    );
  }
}

class _CustomerFilterBottomSheet extends StatefulWidget {
  final Map<String, dynamic> currentFilters;
  final Function(Map<String, dynamic>) onApply;

  const _CustomerFilterBottomSheet({
    Key? key,
    required this.currentFilters,
    required this.onApply,
  }) : super(key: key);

  @override
  State<_CustomerFilterBottomSheet> createState() => _CustomerFilterBottomSheetState();
}

class _CustomerFilterBottomSheetState extends State<_CustomerFilterBottomSheet> {
  late Map<String, dynamic> _filters;
  final TextEditingController _minRevenueController = TextEditingController();
  final TextEditingController _maxRevenueController = TextEditingController();
  final TextEditingController _minOrderCountController = TextEditingController();
  final TextEditingController _maxOrderCountController = TextEditingController();

  DateTime? _revenueStartDate;
  DateTime? _revenueEndDate;
  bool _isLoadingStats = false;

  @override
  void initState() {
    super.initState();
    _filters = Map<String, dynamic>.from(widget.currentFilters);
    _minRevenueController.text = _filters['minRevenue']?.toString() ?? '';
    _maxRevenueController.text = _filters['maxRevenue']?.toString() ?? '';
    _minOrderCountController.text = _filters['minOrderCount']?.toString() ?? '';
    _maxOrderCountController.text = _filters['maxOrderCount']?.toString() ?? '';
    _revenueStartDate = _filters['revenueStartDate'] as DateTime?;
    _revenueEndDate = _filters['revenueEndDate'] as DateTime?;
  }

  @override
  void dispose() {
    _minRevenueController.dispose();
    _maxRevenueController.dispose();
    _minOrderCountController.dispose();
    _maxOrderCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, -1),
              ),
            ],
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    getAdaptiveIcon(iconName: 'filter', defaultIcon:
                      Icons.filter,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Kunden filtern',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: getAdaptiveIcon(iconName: 'close', defaultIcon:Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Umsatz Filter
                      _buildFilterSection(
                        title: 'Umsatz (CHF)',
                        icon: Icons.attach_money,
                        iconName: 'attach_money',
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _minRevenueController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: InputDecoration(
                                      labelText: 'Min',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      prefixText: 'CHF ',
                                    ),
                                    onChanged: (value) {
                                      _filters['minRevenue'] = value.isEmpty ? null : double.tryParse(value);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextField(
                                    controller: _maxRevenueController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: InputDecoration(
                                      labelText: 'Max',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      prefixText: 'CHF ',
                                    ),
                                    onChanged: (value) {
                                      _filters['maxRevenue'] = value.isEmpty ? null : double.tryParse(value);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Zeitraum für Umsatzberechnung
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [

                                      getAdaptiveIcon(iconName: 'date_range', defaultIcon:Icons.date_range, size: 16),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Zeitraum für Umsatzberechnung',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => _selectDate(context, true),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Theme.of(context).dividerColor),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              children: [
                                                 getAdaptiveIcon(iconName: 'calendar_today',defaultIcon:Icons.calendar_today, size: 16),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _revenueStartDate != null
                                                      ? DateFormat('dd.MM.yyyy').format(_revenueStartDate!)
                                                      : 'Von',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: _revenueStartDate != null
                                                        ? null
                                                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('–'),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => _selectDate(context, false),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Theme.of(context).dividerColor),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              children: [
                                                getAdaptiveIcon(iconName: 'calendar_today', defaultIcon:Icons.calendar_today, size: 16),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _revenueEndDate != null
                                                      ? DateFormat('dd.MM.yyyy').format(_revenueEndDate!)
                                                      : 'Bis',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: _revenueEndDate != null
                                                        ? null
                                                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_revenueStartDate != null || _revenueEndDate != null) ...[
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      icon:  getAdaptiveIcon(iconName: 'clear',defaultIcon:Icons.clear, size: 16),
                                      label: const Text('Zeitraum zurücksetzen'),
                                      style: TextButton.styleFrom(
                                        textStyle: const TextStyle(fontSize: 12),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _revenueStartDate = null;
                                          _revenueEndDate = null;
                                          _filters['revenueStartDate'] = null;
                                          _filters['revenueEndDate'] = null;
                                        });
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Anzahl Aufträge
                      _buildFilterSection(
                        title: 'Anzahl Aufträge',
                        icon: Icons.shopping_bag,
                        iconName: 'shopping_bag',
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _minOrderCountController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: InputDecoration(
                                      labelText: 'Min',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      _filters['minOrderCount'] = value.isEmpty ? null : int.tryParse(value);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextField(
                                    controller: _maxOrderCountController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: InputDecoration(
                                      labelText: 'Max',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      _filters['maxOrderCount'] = value.isEmpty ? null : int.tryParse(value);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Bezieht sich auf den gleichen Zeitraum wie der Umsatzfilter',
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Weihnachtskarte
                      _buildFilterSection(
                        title: 'Weihnachtskarte',
                        icon: Icons.card_giftcard,
                        iconName: 'card_giftcard',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Alle'),
                              selected: _filters['wantsChristmasCard'] == null,
                              onSelected: (selected) {
                                setState(() {
                                  _filters['wantsChristmasCard'] = null;
                                });
                              },
                            ),
                            ChoiceChip(
                              label: const Text('JA'),
                              selected: _filters['wantsChristmasCard'] == true,
                              onSelected: (selected) {
                                setState(() {
                                  _filters['wantsChristmasCard'] = selected ? true : null;
                                });
                              },
                            ),
                            ChoiceChip(
                              label: const Text('NEIN'),
                              selected: _filters['wantsChristmasCard'] == false,
                              onSelected: (selected) {
                                setState(() {
                                  _filters['wantsChristmasCard'] = selected ? false : null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Weitere Filter
                      _buildFilterSection(
                        title: 'Weitere Filter',
                        icon: Icons.more_horiz,
                        iconName: 'more_horiz',
                        child: Column(
                          children: [
                            // MwSt-Nummer
                            Row(
                              children: [
                                const Text('MwSt:'),
                                const SizedBox(width: 16),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    ChoiceChip(
                                      label: const Text('Alle'),
                                      selected: _filters['hasVatNumber'] == null,
                                      onSelected: (selected) {
                                        setState(() {
                                          _filters['hasVatNumber'] = null;
                                        });
                                      },
                                    ),
                                    ChoiceChip(
                                      label: const Text('Ja'),
                                      selected: _filters['hasVatNumber'] == true,
                                      onSelected: (selected) {
                                        setState(() {
                                          _filters['hasVatNumber'] = selected ? true : null;
                                        });
                                      },
                                    ),
                                    ChoiceChip(
                                      label: const Text('Fehlt'),
                                      selected: _filters['hasVatNumber'] == false,
                                      onSelected: (selected) {
                                        setState(() {
                                          _filters['hasVatNumber'] = selected ? false : null;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // EORI-Nummer
                            Row(
                              children: [
                                const Text('EORI'),
                                const SizedBox(width: 16),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    ChoiceChip(
                                      label: const Text('Alle'),
                                      selected: _filters['hasEoriNumber'] == null,
                                      onSelected: (selected) {
                                        setState(() {
                                          _filters['hasEoriNumber'] = null;
                                        });
                                      },
                                    ),
                                    ChoiceChip(
                                      label: const Text('Ja'),
                                      selected: _filters['hasEoriNumber'] == true,
                                      onSelected: (selected) {
                                        setState(() {
                                          _filters['hasEoriNumber'] = selected ? true : null;
                                        });
                                      },
                                    ),
                                    ChoiceChip(
                                      label: const Text('Fehlt'),
                                      selected: _filters['hasEoriNumber'] == false,
                                      onSelected: (selected) {
                                        setState(() {
                                          _filters['hasEoriNumber'] = selected ? false : null;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Länder Filter
                      _buildFilterSection(
                        title: 'Länder',
                        icon: Icons.public,
                        iconName: 'public',
                        child: _buildCountrySelection(),
                      ),

                      const SizedBox(height: 24),

                      // Sprachen Filter
                      _buildFilterSection(
                        title: 'Sprachen',
                        icon: Icons.language,
                        iconName: 'language',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              label: const Text('Deutsch'),
                              selected: (_filters['languages'] as List).contains('DE'),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    (_filters['languages'] as List).add('DE');
                                  } else {
                                    (_filters['languages'] as List).remove('DE');
                                  }
                                });
                              },
                            ),
                            FilterChip(
                              label: const Text('Englisch'),
                              selected: (_filters['languages'] as List).contains('EN'),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    (_filters['languages'] as List).add('EN');
                                  } else {
                                    (_filters['languages'] as List).remove('EN');
                                  }
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
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      TextButton.icon(
                        icon:  getAdaptiveIcon(iconName: 'clear', defaultIcon:Icons.clear),
                        label: const Text('Zurücksetzen'),
                        onPressed: () {
                          setState(() {
                            _filters = CustomerFilterService.createEmptyFilter();
                            _minRevenueController.clear();
                            _maxRevenueController.clear();
                            _minOrderCountController.clear();
                            _maxOrderCountController.clear();
                            _revenueStartDate = null;
                            _revenueEndDate = null;
                          });
                        },
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        icon: _isLoadingStats
                            ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        )
                            :  getAdaptiveIcon(iconName: 'check',defaultIcon:Icons.check),
                        label: const Text('Anwenden'),
                        onPressed: _isLoadingStats
                            ? null
                            : () {
                          _filters['revenueStartDate'] = _revenueStartDate;
                          _filters['revenueEndDate'] = _revenueEndDate;
                          widget.onApply(_filters);
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              getAdaptiveIcon(iconName: iconName, defaultIcon:icon, size: 20),
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

  Widget _buildCountrySelection() {
    // Häufigste Länder
    final popularCountries = [
      {'code': 'CH', 'name': 'Schweiz'},
      {'code': 'DE', 'name': 'Deutschland'},
      {'code': 'AT', 'name': 'Österreich'},
      {'code': 'FR', 'name': 'Frankreich'},
      {'code': 'IT', 'name': 'Italien'},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: popularCountries.map((country) {
        final isSelected = (_filters['countries'] as List).contains(country['code']);
        return FilterChip(
          label: Text(country['name']!),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                (_filters['countries'] as List).add(country['code']);
              } else {
                (_filters['countries'] as List).remove(country['code']);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_revenueStartDate ?? DateTime.now())
          : (_revenueEndDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('de', 'CH'),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _revenueStartDate = picked;
        } else {
          _revenueEndDate = picked;
        }
      });
    }
  }
}