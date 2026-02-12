import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../components/filterCategory.dart';
import '../../../services/countries.dart';
import '../../../services/icon_helper.dart';
import '../models/sales_filter.dart';

class SalesFilterDialog extends StatefulWidget {
  final SalesFilter initialFilter;

  const SalesFilterDialog({
    Key? key,
    required this.initialFilter,
  }) : super(key: key);

  @override
  SalesFilterDialogState createState() => SalesFilterDialogState();
}

class SalesFilterDialogState extends State<SalesFilterDialog> {
  late SalesFilter tempFilter;
  final TextEditingController minController = TextEditingController();
  final TextEditingController maxController = TextEditingController();

  @override
  void initState() {
    super.initState();
    tempFilter = widget.initialFilter;
    minController.text = tempFilter.minAmount?.toString() ?? '';
    maxController.text = tempFilter.maxAmount?.toString() ?? '';
  }

  @override
  void dispose() {
    minController.dispose();
    maxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            _buildHeader(),
            if (_hasActiveFilters()) _buildActiveFiltersBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      child: Theme(
                          data: ThemeData(dividerColor: Colors.transparent),
                          child: Column(
                            children: [
                              buildFilterCategory(
                                icon: Icons.calendar_today,
                                iconName: 'calendar_today',
                                title:  'Zeitraum',
                                child:   _buildDateFilter(),
                                hasActiveFilters:  tempFilter.timeRange != null || tempFilter.startDate != null,
                              ),
                              buildFilterCategory(
                                icon:  Icons.savings,
                                iconName: 'money_bag',
                                title:     'Betrag',
                                child:   _buildAmountFilter(),
                                hasActiveFilters:   tempFilter.minAmount != null || tempFilter.maxAmount != null,
                              ),
                              buildFilterCategory(
                                icon: Icons.event,
                                iconName: 'event',
                                title:    'Messe',
                                child:   _buildFairFilter(),
                                hasActiveFilters:    tempFilter.selectedFairs != null,
                              ),
                              buildFilterCategory(
                                icon:  Icons.inventory,
                                iconName: 'inventory',
                                title:    'Artikel',
                                child:    _buildProductFilter(),
                                hasActiveFilters:    tempFilter.selectedProducts != null,
                              ),
                              buildFilterCategory(
                                icon:   Icons.forest,
                                iconName: 'forest',
                                title:   'Holzart',
                                child:  _buildWoodTypeFilter(),
                                hasActiveFilters:    tempFilter.woodTypes?.isNotEmpty ?? false,
                              ),
                              buildFilterCategory(
                                icon:  Icons.category,
                                iconName: 'category',
                                title:     'Bauteil',
                                child:   _buildPartsFilter(),
                                hasActiveFilters:   tempFilter.parts?.isNotEmpty ?? false,
                              ),
                              buildFilterCategory(
                                icon:   Icons.music_note,
                                iconName: 'music_note',
                                title:   'Instrument',
                                child:  _buildInstrumentFilter(),
                                hasActiveFilters:    tempFilter.instruments?.isNotEmpty ?? false,
                              ),
                              buildFilterCategory(
                                icon:   Icons.star,
                                iconName: 'star',
                                title:    'Qualität',
                                child:    _buildQualityFilter(),
                                hasActiveFilters:   tempFilter.qualities?.isNotEmpty ?? false,
                              ),
                              buildFilterCategory(
                                icon:  Icons.person,
                                iconName: 'person',
                                title:    'Kunde',
                                child: _buildCustomerFilter(),
                                hasActiveFilters:   tempFilter.selectedCustomers != null,
                              ),
                              buildFilterCategory(
                                icon: Icons.account_balance_wallet,
                                iconName: 'account_balance_wallet',
                                title: 'Kostenstelle',
                                child: _buildCostCenterFilter(),
                                hasActiveFilters: tempFilter.costCenters?.isNotEmpty ?? false,
                              ),
                              buildFilterCategory(
                                icon: Icons.storefront,
                                iconName: 'storefront',
                                title: 'Bestellart',
                                child: _buildDistributionChannelFilter(),
                                hasActiveFilters: tempFilter.distributionChannels?.isNotEmpty ?? false,
                              ),
                              buildFilterCategory(
                                icon: Icons.public,
                                iconName: 'public',
                                title: 'Land',
                                child: _buildCountryFilter(),
                                hasActiveFilters: tempFilter.countries?.isNotEmpty ?? false,
                              ),
                            ],
                          )
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F4A29).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:  getAdaptiveIcon(iconName: 'filter_list', defaultIcon: Icons.filter_list, color: Color(0xFF0F4A29)),
              ),
              const SizedBox(width: 12),
              const Text(
                'Filter',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F4A29),
                ),
              ),
            ],
          ),
          const Spacer(),
          if (_hasActiveFilters())
            TextButton.icon(
              icon: getAdaptiveIcon(iconName: 'clear_all', defaultIcon: Icons.clear_all,),
              label: const Text('Zurücksetzen'),
              onPressed: _resetFilters,
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          IconButton(
            icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,),
            onPressed: () => Navigator.of(context).pop(),
            color: Colors.grey[600],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (tempFilter.timeRange != null || tempFilter.startDate != null)
            _buildTimeRangeChip(),
          if (tempFilter.minAmount != null || tempFilter.maxAmount != null)
            _buildAmountChip(),
          if (tempFilter.woodTypes?.isNotEmpty ?? false)
            ...tempFilter.woodTypes!.map(_buildWoodTypeChip),
          if (tempFilter.qualities?.isNotEmpty ?? false)
            ...tempFilter.qualities!.map(_buildQualityChip),
          if (tempFilter.parts?.isNotEmpty ?? false)
            ...tempFilter.parts!.map(_buildPartChip),
          if (tempFilter.selectedFairs != null)
            _buildFairChips(),
          if (tempFilter.selectedProducts?.isNotEmpty ?? false)
            _buildProductChips(),
          if (tempFilter.instruments?.isNotEmpty ?? false)
            ...tempFilter.instruments!.map(_buildInstrumentChip),
          if (tempFilter.selectedCustomers != null)
            _buildCustomerChips(),
          if (tempFilter.costCenters?.isNotEmpty ?? false)
            ...tempFilter.costCenters!.map(_buildCostCenterChip),
          if (tempFilter.distributionChannels?.isNotEmpty ?? false)
            ...tempFilter.distributionChannels!.map(_buildDistributionChannelChip),
        ],
      ),
    );
  }


  Widget _buildDateFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('Woche'),
              selected: tempFilter.timeRange == 'week',
              onSelected: (selected) {
                setState(() {
                  tempFilter = tempFilter.copyWith(
                    timeRange: selected ? 'week' : null,
                    startDate: null,
                    endDate: null,
                  );
                });
              },
            ),
            FilterChip(
              label: const Text('Monat'),
              selected: tempFilter.timeRange == 'month',
              onSelected: (selected) {
                setState(() {
                  tempFilter = tempFilter.copyWith(
                    timeRange: selected ? 'month' : null,
                    startDate: null,
                    endDate: null,
                  );
                });
              },
            ),
            FilterChip(
              label: const Text('Quartal'),
              selected: tempFilter.timeRange == 'quarter',
              onSelected: (selected) {
                setState(() {
                  tempFilter = tempFilter.copyWith(
                    timeRange: selected ? 'quarter' : null,
                    startDate: null,
                    endDate: null,
                  );
                });
              },
            ),
            FilterChip(
              label: const Text('Jahr'),
              selected: tempFilter.timeRange == 'year',
              onSelected: (selected) {
                setState(() {
                  tempFilter = tempFilter.copyWith(
                    timeRange: selected ? 'year' : null,
                    startDate: null,
                    endDate: null,
                  );
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Oder Zeitraum wählen:',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'Von',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: getAdaptiveIcon(iconName: 'calendar_today', defaultIcon: Icons.calendar_today),
                ),
                readOnly: true,
                controller: TextEditingController(
                  text: tempFilter.startDate != null
                      ? DateFormat('dd.MM.yyyy').format(tempFilter.startDate!)
                      : '',
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: tempFilter.startDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() {
                      tempFilter = tempFilter.copyWith(
                        startDate: date,
                        timeRange: null,
                      );
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'Bis',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: getAdaptiveIcon(iconName: 'calendar_today', defaultIcon: Icons.calendar_today),
                ),
                readOnly: true,
                controller: TextEditingController(
                  text: tempFilter.endDate != null
                      ? DateFormat('dd.MM.yyyy').format(tempFilter.endDate!)
                      : '',
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: tempFilter.endDate ?? DateTime.now(),
                    firstDate: tempFilter.startDate ?? DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() {
                      tempFilter = tempFilter.copyWith(
                        endDate: date,
                        timeRange: null,
                      );
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAmountFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: minController,
                decoration: InputDecoration(
                  labelText: 'Mindestbetrag',
                  suffixText: 'CHF',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  setState(() {
                    tempFilter = tempFilter.copyWith(
                      minAmount: double.tryParse(value),
                    );
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: maxController,
                decoration: InputDecoration(
                  labelText: 'Maximalbetrag',
                  suffixText: 'CHF',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  setState(() {
                    tempFilter = tempFilter.copyWith(
                      maxAmount: double.tryParse(value),
                    );
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWoodTypeFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('wood_types')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        return _buildMultiSelectDropdown(
          label: 'Holzart auswählen',
          options: snapshot.data!.docs,
          selectedValues: tempFilter.woodTypes ?? [], // Liste statt einzelner Wert
          onChanged: (newSelection) {
            setState(() {
              tempFilter = tempFilter.copyWith(woodTypes: newSelection); // Direkt die Liste übergeben
            });
          },
        );
      },
    );
  }
  Widget _buildInstrumentFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('instruments')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        return _buildMultiSelectDropdown(
          label: 'Instrument auswählen',
          options: snapshot.data!.docs,
          selectedValues: tempFilter.instruments ?? [],
          onChanged: (newSelection) {
            setState(() {
              tempFilter = tempFilter.copyWith(instruments: newSelection);
            });
          },
        );
      },
    );
  }
  Widget _buildPartsFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('parts')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        return _buildMultiSelectDropdown(
          label: 'Bauteil auswählen',
          options: snapshot.data!.docs,
          selectedValues: tempFilter.parts ?? [], // Liste statt einzelner Wert
          onChanged: (newSelection) {
            setState(() {
              tempFilter = tempFilter.copyWith(parts: newSelection); // Direkt die Liste übergeben
            });
          },
        );
      },
    );
  }

  Widget _buildQualityFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('qualities')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        return _buildMultiSelectDropdown(
          label: 'Qualität auswählen',
          options: snapshot.data!.docs,
          selectedValues: tempFilter.qualities ?? [], // Liste statt einzelner Wert
          onChanged: (newSelection) {
            setState(() {
              tempFilter = tempFilter.copyWith(qualities: newSelection); // Direkt die Liste übergeben
            });
          },
        );
      },
    );
  }

  Widget _buildCustomerFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('customers')
          .orderBy('company')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        return _buildMultiSelectDropdown(
          label: 'Firma auswählen',
          options: snapshot.data!.docs,
          selectedValues: tempFilter.selectedCustomers ?? [],
          onChanged: (newSelection) {
            setState(() {
              tempFilter = tempFilter.copyWith(
                  selectedCustomers: newSelection
              );
            });
          },
        );
      },
    );
  }

  Widget _buildProductFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('inventory')
          .orderBy('product_name')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        return _buildMultiSelectDropdown(
          label: 'Artikel auswählen',
          options: snapshot.data!.docs,
          selectedValues: tempFilter.selectedProducts ?? [], // Plural!
          onChanged: (newSelection) {
            setState(() {
              tempFilter = tempFilter.copyWith(
                selectedProducts: newSelection, // Direkt die Liste übergeben
              );
            });
          },
        );
      },
    );
  }

  Widget _buildFairFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('fairs')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        return _buildMultiSelectDropdown(
          label: 'Messe auswählen',
          options: snapshot.data!.docs,
          selectedValues: tempFilter.selectedFairs ?? [], // Plural und optional
          onChanged: (newSelection) {
            setState(() {
              tempFilter = tempFilter.copyWith(
                selectedFairs: newSelection, // Direkt die Liste übergeben
              );
            });
          },
        );
      },
    );
  }
  Widget _buildCountryFilter() {
    final allCountries = Countries.allCountries;
    final selected = tempFilter.countries ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selected.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: selected.map((code) {
              final country = Countries.getCountryByCode(code);
              return Chip(
                backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
                label: Text(country.name),
                deleteIcon: getAdaptiveIcon(
                    iconName: 'close', defaultIcon: Icons.close, size: 18),
                onDeleted: () {
                  setState(() {
                    tempFilter = tempFilter.copyWith(
                      countries: selected.where((c) => c != code).toList(),
                    );
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        _CountrySearchField(
          selectedCodes: selected,
          onChanged: (newSelection) {
            setState(() {
              tempFilter = tempFilter.copyWith(countries: newSelection);
            });
          },
        ),
      ],
    );
  }







  Widget _buildCostCenterFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cost_centers')
          .orderBy('code')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        // Nur aktive Kostenstellen anzeigen
        final activeDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['isActive'] ?? true;
        }).toList();

        return _buildMultiSelectDropdown(
          label: 'Kostenstelle auswählen',
          options: activeDocs,
          selectedValues: tempFilter.costCenters ?? [],
          onChanged: (newSelection) {
            setState(() {
              tempFilter = tempFilter.copyWith(costCenters: newSelection);
            });
          },
        );
      },
    );
  }

  Widget _buildCostCenterChip(String id) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cost_centers')
          .doc(id)
          .snapshots(),
      builder: (context, snapshot) {
        String name = id;
        if (snapshot.hasData && snapshot.data!.data() != null) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final code = data['code'] ?? '';
          final ccName = data['name'] ?? '';
          name = code.isNotEmpty ? '$code - $ccName' : ccName;
        }
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Chip(
            backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
            label: Text(name),
            deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close, size: 18),
            onDeleted: () {
              setState(() {
                tempFilter = tempFilter.copyWith(
                  costCenters: tempFilter.costCenters?.where((c) => c != id).toList(),
                );
              });
            },
          ),
        );
      },
    );
  }



  Widget _buildDistributionChannelFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('distribution_channel')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        return _buildMultiSelectDropdown(
          label: 'Bestellart auswählen',
          options: snapshot.data!.docs,
          selectedValues: tempFilter.distributionChannels ?? [],
          onChanged: (newSelection) {
            setState(() {
              tempFilter = tempFilter.copyWith(distributionChannels: newSelection);
            });
          },
        );
      },
    );
  }

  Widget _buildDistributionChannelChip(String id) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('distribution_channel')
          .doc(id)
          .snapshots(),
      builder: (context, snapshot) {
        String name = id;
        if (snapshot.hasData && snapshot.data!.data() != null) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          name = data['name'] ?? id;
        }
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Chip(
            backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
            label: Text(name),
            deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close, size: 18),
            onDeleted: () {
              setState(() {
                tempFilter = tempFilter.copyWith(
                  distributionChannels: tempFilter.distributionChannels?.where((c) => c != id).toList(),
                );
              });
            },
          ),
        );
      },
    );
  }



  bool _hasActiveFilters() {
    return tempFilter.timeRange != null ||
        tempFilter.startDate != null ||
        tempFilter.endDate != null ||
        tempFilter.minAmount != null ||
        tempFilter.maxAmount != null ||
        tempFilter.selectedFairs != null ||
        tempFilter.selectedCustomers != null ||
        (tempFilter.selectedProducts?.isNotEmpty ?? false) ||
        (tempFilter.woodTypes?.isNotEmpty ?? false) ||
        (tempFilter.qualities?.isNotEmpty ?? false) ||
        (tempFilter.parts?.isNotEmpty ?? false) ||
        (tempFilter.instruments?.isNotEmpty ?? false) ||
        (tempFilter.costCenters?.isNotEmpty ?? false) ||
        (tempFilter.countries?.isNotEmpty ?? false) ||
        (tempFilter.distributionChannels?.isNotEmpty ?? false);
  }

  void _resetFilters() {
    setState(() {
      tempFilter = SalesFilter();
      minController.clear();
      maxController.clear();
    });
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[700],
              side: BorderSide(color: Colors.grey[300]!),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Abbrechen'),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(tempFilter),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F4A29),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Anwenden'),
          ),
        ],
      ),
    );
  }
  Widget _buildInstrumentChip(String code) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('instruments')
          .doc(code)
          .snapshots(),
      builder: (context, snapshot) {
        final name = snapshot.hasData && snapshot.data!.data() != null
            ? (snapshot.data!.data() as Map<String, dynamic>)['name'] ?? code
            : code;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Chip(
            backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
            label: Text(name),
            deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
            onDeleted: () {
              setState(() {
                tempFilter = tempFilter.copyWith(
                  instruments: tempFilter.instruments?.where((t) => t != code).toList(),
                );
              });
            },
          ),
        );
      },
    );
  }
  Widget _buildTimeRangeChip() {
    String timeText = '';
    if (tempFilter.timeRange != null) {
      switch (tempFilter.timeRange) {
        case 'week':
          timeText = 'Woche';
          break;
        case 'month':
          timeText = 'Monat';
          break;
        case 'quarter':
          timeText = 'Quartal';
          break;
        case 'year':
          timeText = 'Jahr';
          break;
      }
    } else if (tempFilter.startDate != null && tempFilter.endDate != null) {
      timeText =
      '${DateFormat('dd.MM.yy').format(tempFilter.startDate!)} - ${DateFormat('dd.MM.yy').format(tempFilter.endDate!)}';
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
        label: Text('Zeitraum: $timeText'),
        deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
        onDeleted: () => setState(() {
          tempFilter = tempFilter.copyWith(
            timeRange: null,
            startDate: null,
            endDate: null,
          );
        }),
      ),
    );
  }
  Widget _buildPartChip(String code) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('parts')
          .doc(code)
          .snapshots(),
      builder: (context, snapshot) {
        final name = snapshot.hasData
            ? (snapshot.data!.data() as Map<String, dynamic>)['name'] ?? code
            : code;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Chip(
            backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
            label: Text(name),
            deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
            onDeleted: () {
              setState(() {
                tempFilter = tempFilter.copyWith(
                  parts: tempFilter.parts?.where((t) => t != code).toList(),
                );
              });
            },
          ),
        );
      },
    );
  }
  Widget _buildAmountChip() {
    String amountText = '';
    if (tempFilter.minAmount != null && tempFilter.maxAmount != null) {
      amountText = '${tempFilter.minAmount!.toStringAsFixed(2)} - ${tempFilter.maxAmount!.toStringAsFixed(2)} CHF';
    } else if (tempFilter.minAmount != null) {
      amountText = 'Min: ${tempFilter.minAmount!.toStringAsFixed(2)} CHF';
    } else if (tempFilter.maxAmount != null) {
      amountText = 'Max: ${tempFilter.maxAmount!.toStringAsFixed(2)} CHF';
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
        label: Text('Betrag: $amountText'),
        deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
        onDeleted: () => setState(() {
          tempFilter = tempFilter.copyWith(
            minAmount: null,
            maxAmount: null,
          );
          minController.clear();
          maxController.clear();
        }),
      ),
    );
  }
  Widget _buildWoodTypeChip(String code) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('wood_types')
          .doc(code)
          .snapshots(),
      builder: (context, snapshot) {
        final name = snapshot.hasData
            ? (snapshot.data!.data() as Map<String, dynamic>)['name'] ?? code
            : code;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Chip(
            backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
            label: Text(name),
            deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
            onDeleted: () {
              setState(() {
                tempFilter = tempFilter.copyWith(
                  woodTypes: tempFilter.woodTypes?.where((t) => t != code).toList(),
                );
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildQualityChip(String code) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('qualities')
          .doc(code)
          .snapshots(),
      builder: (context, snapshot) {
        final name = snapshot.hasData
            ? (snapshot.data!.data() as Map<String, dynamic>)['name'] ?? code
            : code;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Chip(
            backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
            label: Text(name),
            deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
            onDeleted: () {
              setState(() {
                tempFilter = tempFilter.copyWith(
                  qualities: tempFilter.qualities?.where((q) => q != code).toList(),
                );
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildCustomerChips() {
    if (tempFilter.selectedCustomers == null || tempFilter.selectedCustomers!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: tempFilter.selectedCustomers!.map((customerId) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('customers')
              .doc(customerId)
              .snapshots(),
          builder: (context, snapshot) {
            final name = snapshot.hasData
                ? (snapshot.data!.data() as Map<String, dynamic>)['company'] ?? 'Unbekannte Firma'
                : 'Lädt...';

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
                label: Text('Firma: $name'),
                deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
                onDeleted: () => setState(() {
                  tempFilter = tempFilter.copyWith(
                    selectedCustomers: tempFilter.selectedCustomers!
                        .where((id) => id != customerId)
                        .toList(),
                  );
                }),
              ),
            );
          },
        );
      }).toList(),
    );
  }
  Widget _buildFairChips() {  // Plural!
    if (tempFilter.selectedFairs == null || tempFilter.selectedFairs!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: tempFilter.selectedFairs!.map((fairId) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('fairs')
              .doc(fairId)
              .snapshots(),
          builder: (context, snapshot) {
            final name = snapshot.hasData
                ? (snapshot.data!.data() as Map<String, dynamic>)['name'] ?? 'Unbekannte Messe'
                : 'Lädt...';

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
                label: Text('Messe: $name'),
                deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
                onDeleted: () => setState(() {
                  tempFilter = tempFilter.copyWith(
                    selectedFairs: tempFilter.selectedFairs!
                        .where((id) => id != fairId)
                        .toList(),
                  );
                }),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildProductChips() {
    if (tempFilter.selectedProducts == null || tempFilter.selectedProducts!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: tempFilter.selectedProducts!.map((productId) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('inventory')
              .doc(productId)
              .snapshots(),
          builder: (context, snapshot) {
            // Füge zusätzliche Null-Checks hinzu
            final name = snapshot.hasData && snapshot.data != null && snapshot.data!.data() != null
                ? (snapshot.data!.data() as Map<String, dynamic>)['product_name'] ?? 'Unbekannter Artikel'
                : 'Lädt...';

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                backgroundColor: const Color(0xFF0F4A29).withOpacity(0.1),
                label: Text('Artikel: $name'),
                deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
                onDeleted: () => setState(() {
                  tempFilter = tempFilter.copyWith(
                    selectedProducts: tempFilter.selectedProducts!
                        .where((id) => id != productId)
                        .toList(),
                  );
                }),
              ),
            );
          },
        );
      }).toList(),
    );
  }
  Widget _buildMultiSelectDropdown({
    required String label,
    required List<DocumentSnapshot> options,
    required List<String> selectedValues,
    required Function(List<String>) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child:
      Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        constraints: const BoxConstraints(maxHeight: 250),
        child: ListView(
          shrinkWrap: true,
          children: options.map((option) {
            final data = option.data() as Map<String, dynamic>;
            final isSelected = selectedValues.contains(option.id);

            final code = data['code'] as String?;
            final rawName = data['name'] as String? ??
                data['company'] as String? ??
                data['product_name'] as String? ??
                'Unbekannt';
            final displayName = (code != null && code.isNotEmpty && data.containsKey('isActive'))
                ? '$code - $rawName'
                : rawName;

            return CheckboxListTile(
              title: Text(displayName),
              value: isSelected,
              onChanged: (bool? checked) {
                if (checked == true) {
                  // Zu bestehender Auswahl hinzufügen
                  onChanged([...selectedValues, option.id]);
                } else {
                  // Element aus Auswahl entfernen
                  onChanged(
                    selectedValues.where((id) => id != option.id).toList(),
                  );
                }
              },
              activeColor: const Color(0xFF0F4A29),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            );
          }).toList(),
        ),
      ),

    );
  }

  String _getSelectedItemsLabel(List<DocumentSnapshot> options, List<String> selectedValues) {
    if (selectedValues.isEmpty) return '';

    final selectedDocs = options.where((doc) => selectedValues.contains(doc.id));
    if (selectedDocs.isEmpty) return '';

    final data = selectedDocs.first.data() as Map<String, dynamic>;
    final name = data['product_name'] as String? ?? data['name'] as String;

    if (selectedValues.length > 1) {
      return '$name + ${selectedValues.length - 1} weitere';
    }
    return name;
  }}
class _CountrySearchField extends StatefulWidget {
  final List<String> selectedCodes;
  final Function(List<String>) onChanged;

  const _CountrySearchField({
    required this.selectedCodes,
    required this.onChanged,
  });

  @override
  State<_CountrySearchField> createState() => _CountrySearchFieldState();
}

class _CountrySearchFieldState extends State<_CountrySearchField> {
  final TextEditingController _searchController = TextEditingController();
  List<Country> _filteredCountries = [];
  bool _showResults = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCountries = [];
        _showResults = false;
      } else {
        _filteredCountries = Countries.searchCountriesByName(query)
            .where((c) => !widget.selectedCodes.contains(c.code))
            .toList();
        _showResults = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Land suchen...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onChanged: _onSearch,
        ),
        if (_showResults && _filteredCountries.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filteredCountries.length,
              itemBuilder: (context, index) {
                final country = _filteredCountries[index];
                return ListTile(
                  dense: true,
                  title: Text(country.name),
                  trailing: Text(country.code,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  onTap: () {
                    widget.onChanged([...widget.selectedCodes, country.code]);
                    _searchController.clear();
                    setState(() {
                      _showResults = false;
                      _filteredCountries = [];
                    });
                  },
                );
              },
            ),
          ),
        if (!_showResults && widget.selectedCodes.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: Countries.popularCountries.map((country) {
                return ActionChip(
                  label: Text(country.name,
                      style: const TextStyle(fontSize: 12)),
                  onPressed: () {
                    widget
                        .onChanged([...widget.selectedCodes, country.code]);
                  },
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}