import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/filterCategory.dart';
import '../constants.dart';
import 'dart:convert';

import 'package:universal_html/html.dart' as html;

import 'package:flutter/services.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io' if (dart.library.html) 'dart:html' as html;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

import 'dart:typed_data';

import '../services/download_helper_mobile.dart' if (dart.library.html) '../services/download_helper_web.dart';

import 'package:csv/csv.dart';
import 'dart:math' as math;

import '../services/icon_helper.dart';
import '../services/production_analytics_service.dart';
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  AnalyticsScreenState createState() => AnalyticsScreenState();
}

class AnalyticsScreenState extends State<AnalyticsScreen> {
  List<QueryDocumentSnapshot>? purposes;  // Für die Verwendungszwecke aus der DB
  List<String> selectedPurposeCodes = []; // Für die ausgewählten Verwendungszwecke
  final TextEditingController additionalPurposeController = TextEditingController();

  String selectedMainSection = 'roundwood'; // 'roundwood' oder 'sales'
  String selectedRoundwoodSection = 'list'; // 'list' oder 'analysis'
  String selectedTimeRange = 'month';
  String selectedTab = 'list';
  bool isLoading = false;
  Map<String, dynamic> activeFilters = {};

  @override
  void dispose() {
    additionalPurposeController.dispose();
    super.dispose();
  }

  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopLayout = screenWidth > ResponsiveBreakpoints.tablet;

    return Scaffold(
      appBar: AppBar(
        title:
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hauptnavigations-Buttons in der AppBar
            ElevatedButton(
              onPressed: () => setState(() {
                selectedMainSection = 'roundwood';
                selectedRoundwoodSection = 'list';
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedMainSection == 'roundwood'
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceVariant,
                foregroundColor: selectedMainSection == 'roundwood'
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Rundholz'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => setState(() {
                selectedMainSection = 'sales';
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedMainSection == 'sales'
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceVariant,
                foregroundColor: selectedMainSection == 'sales'
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Verkauf'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => setState(() {
                selectedMainSection = 'production';
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedMainSection == 'production'
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceVariant,
                foregroundColor: selectedMainSection == 'production'
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Produktion'),
            ),
          ],
        ),
        actions: [
          // Zeitraumauswahl
          // Padding(
          //   padding: const EdgeInsets.all(8.0),
          //   child: DropdownButton<String>(
          //     value: selectedTimeRange,
          //     items: const [
          //       DropdownMenuItem(value: 'week', child: Text('Woche')),
          //       DropdownMenuItem(value: 'month', child: Text('Monat')),
          //       DropdownMenuItem(value: 'quarter', child: Text('Quartal')),
          //       DropdownMenuItem(value: 'year', child: Text('Jahr')),
          //     ],
          //     onChanged: (value) {
          //       if (value != null) {
          //         setState(() => selectedTimeRange = value);
          //       }
          //     },
          //   ),
          // ),
        ],
      ),
      body: isDesktopLayout ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        // Horizontale Navigation (die mittlere Navigationsleiste)
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _buildNavigationItems(),
            ),
          ),
        ),
        // Hauptinhalt
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildSelectedContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Horizontale Navigation
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: Theme.of(context).colorScheme.surface,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: _buildNavigationItems(),
            ),
          ),
        ),
        // Hauptinhalt
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16,4,16,8),
            child: _buildSelectedContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildSubNavigationButton(String section, String label) {
    final isSelected = selectedRoundwoodSection == section;
    return ElevatedButton(
      onPressed: () => setState(() => selectedRoundwoodSection = section),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.secondary
            : Theme.of(context).colorScheme.surfaceVariant,
        foregroundColor: isSelected
            ? Theme.of(context).colorScheme.onSecondary
            : Theme.of(context).colorScheme.onSurfaceVariant,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(label),
    );
  }
  Widget _buildMainContent(bool isDesktopLayout) {
    if (selectedMainSection == 'roundwood') {
      return selectedRoundwoodSection == 'list'
          ? _buildRoundwoodList()
          : _buildRoundwoodSection(); // die bisherige Auswertung
    } else {
      return _buildSalesSection();
    }
  }
  Future<List<QueryDocumentSnapshot>> _getFilteredRoundwoodData() async {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('roundwood');

    if (activeFilters['purpose_codes'] != null) {
      final purposeCodes = activeFilters['purpose_codes'] as List<String>;
      if (purposeCodes.isNotEmpty) {
        query = query.where('purpose_codes', arrayContainsAny: purposeCodes);
      }
    }

    if (activeFilters['additional_purpose'] != null) {
      query = query.where('additional_purpose',
          isEqualTo: activeFilters['additional_purpose']);
    }

    // Anwenden der Filter
    activeFilters.forEach((key, value) {
      switch (key) {
        case 'wood_type':
        case 'quality':
        case 'origin':
          query = query.where(key, isEqualTo: value);
          break;
        case 'is_moonwood':
          query = query.where(key, isEqualTo: value == 'true');
          break;
      }
    });

    final snapshot = await query.get();
    return snapshot.docs;
  }
  Future<void> _sharePdf(Uint8List pdfBytes) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/Rundholz_Liste.pdf');
      await tempFile.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        subject: 'Rundholz Liste',
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
            content: Text('Fehler beim Teilen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Future<void> _shareCsv(Uint8List csvBytes) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/Rundholz_Liste.csv');
      await tempFile.writeAsBytes(csvBytes);

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        subject: 'Rundholz Liste CSV',
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
            content: Text('Fehler beim Teilen der CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  void _showFilterDialog() {
    // Tiefe Kopie der aktiven Filter
    final tempFilters = Map<String, dynamic>.from(activeFilters);
   var tempPurposeCodes = List<String>.from(selectedPurposeCodes);
    final tempAdditionalPurpose = TextEditingController(
        text: additionalPurposeController.text
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
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
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16.0),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F4A29).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child:  getAdaptiveIcon(iconName: 'filter_list', defaultIcon: Icons.filter_list,
                                  color: Color(0xFF0F4A29),
                                ),
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
                          IconButton(
                            icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,),
                            onPressed: () => Navigator.of(context).pop(),
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Holzart Filter
                              buildFilterCategory(
                                iconName: 'forest',
                                icon: Icons.forest,
                                title: 'Holzart',
                                child: StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('wood_types')
                                      .orderBy('name')
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) return const CircularProgressIndicator();

                                    return _buildMultiSelectDropdown(
                                      label: 'Holzart auswählen',
                                      options: snapshot.data!.docs,
                                      selectedValues: tempFilters['wood_types'] ?? [],
                                      onChanged: (newSelection) {
                                        setState(() {
                                          tempFilters['wood_types'] = newSelection;
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Qualität Filter
                              buildFilterCategory(
                                iconName: 'stars',
                                icon: Icons.stars,
                                title: 'Qualität',
                                child: StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('qualities')
                                      .orderBy('name')
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) return const CircularProgressIndicator();

                                    return _buildMultiSelectDropdown(
                                      label: 'Qualität auswählen',
                                      options: snapshot.data!.docs,
                                      selectedValues: tempFilters['qualities'] ?? [],
                                      onChanged: (newSelection) {
                                        setState(() {
                                          tempFilters['qualities'] = newSelection;
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Verwendungszweck Filter
                              buildFilterCategory(
                                iconName: 'assignment',
                                icon: Icons.assignment,
                                title: 'Verwendungszweck',
                                child: StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('parts')
                                      .orderBy('name')
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) return const CircularProgressIndicator();

                                    return _buildMultiSelectDropdown(
                                      label: 'Verwendungszweck auswählen',
                                      options: snapshot.data!.docs,
                                      selectedValues: tempPurposeCodes,
                                      onChanged: (newSelection) {
                                        setState(() {
                                          tempPurposeCodes = newSelection;
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Zusätzlicher Verwendungszweck
                              buildFilterCategory(
                                iconName: 'add',
                                icon: Icons.add,
                                title: 'Zusätzlicher Verwendungszweck',
                                child: TextFormField(
                                  controller: tempAdditionalPurpose,
                                  decoration: InputDecoration(
                                    hintText: 'Weiterer Verwendungszweck',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Herkunft Filter
                              buildFilterCategory(
                                iconName: 'location',
                                icon: Icons.location_on,
                                title: 'Herkunft',
                                child: TextFormField(
                                  initialValue: tempFilters['origin'],
                                  decoration: InputDecoration(
                                    hintText: 'z.B. Schweiz',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      if (value.isEmpty) {
                                        tempFilters.remove('origin');
                                      } else {
                                        tempFilters['origin'] = value;
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Volumen Range Filter
                              buildFilterCategory(
                                iconName: 'straighten',
                                icon: Icons.straighten,
                                title: 'Volumen',
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: tempFilters['volume_min']?.toString(),
                                        decoration: InputDecoration(
                                          labelText: 'Minimum (m³)',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (value) {
                                          setState(() {
                                            if (value.isEmpty) {
                                              tempFilters.remove('volume_min');
                                            } else {
                                              tempFilters['volume_min'] = double.tryParse(value);
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: tempFilters['volume_max']?.toString(),
                                        decoration: InputDecoration(
                                          labelText: 'Maximum (m³)',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (value) {
                                          setState(() {
                                            if (value.isEmpty) {
                                              tempFilters.remove('volume_max');
                                            } else {
                                              tempFilters['volume_max'] = double.tryParse(value);
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Mondholz Filter
                              buildFilterCategory(
                                iconName: 'nightlight',
                                icon: Icons.nightlight,
                                title: 'Spezielle Filter',
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: SwitchListTile(
                                    title: const Text('Nur Mondholz'),
                                    value: tempFilters['is_moonwood'] == true,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value) {
                                          tempFilters['is_moonwood'] = true;
                                        } else {
                                          tempFilters.remove('is_moonwood');
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ),
                              buildFilterCategory(
                                iconName: 'calendar_today',
                                icon:getAdaptiveIcon(iconName: 'calendar_today', defaultIcon: Icons.calendar_today),
                                title: 'Zeitraum',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Schnellauswahl
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        FilterChip(
                                          label: const Text('Woche'),
                                          selected: tempFilters['timeRange'] == 'week',
                                          onSelected: (selected) {
                                            setState(() {
                                              if (selected) {
                                                tempFilters['timeRange'] = 'week';
                                                tempFilters['startDate'] = DateTime.now().subtract(const Duration(days: 7));
                                                tempFilters['endDate'] = DateTime.now();
                                                // Custom Range löschen wenn Schnellauswahl
                                                tempFilters.remove('customStartDate');
                                                tempFilters.remove('customEndDate');
                                              } else {
                                                tempFilters.remove('timeRange');
                                                tempFilters.remove('startDate');
                                                tempFilters.remove('endDate');
                                              }
                                            });
                                          },
                                        ),
                                        FilterChip(
                                          label: const Text('Monat'),
                                          selected: tempFilters['timeRange'] == 'month',
                                          onSelected: (selected) {
                                            setState(() {
                                              if (selected) {
                                                tempFilters['timeRange'] = 'month';
                                                tempFilters['startDate'] = DateTime.now().subtract(const Duration(days: 30));
                                                tempFilters['endDate'] = DateTime.now();
                                                tempFilters.remove('customStartDate');
                                                tempFilters.remove('customEndDate');
                                              } else {
                                                tempFilters.remove('timeRange');
                                                tempFilters.remove('startDate');
                                                tempFilters.remove('endDate');
                                              }
                                            });
                                          },
                                        ),
                                        FilterChip(
                                          label: const Text('Quartal'),
                                          selected: tempFilters['timeRange'] == 'quarter',
                                          onSelected: (selected) {
                                            setState(() {
                                              if (selected) {
                                                tempFilters['timeRange'] = 'quarter';
                                                tempFilters['startDate'] = DateTime.now().subtract(const Duration(days: 90));
                                                tempFilters['endDate'] = DateTime.now();
                                                tempFilters.remove('customStartDate');
                                                tempFilters.remove('customEndDate');
                                              } else {
                                                tempFilters.remove('timeRange');
                                                tempFilters.remove('startDate');
                                                tempFilters.remove('endDate');
                                              }
                                            });
                                          },
                                        ),
                                        FilterChip(
                                          label: const Text('Jahr'),
                                          selected: tempFilters['timeRange'] == 'year',
                                          onSelected: (selected) {
                                            setState(() {
                                              if (selected) {
                                                tempFilters['timeRange'] = 'year';
                                                tempFilters['startDate'] = DateTime.now().subtract(const Duration(days: 365));
                                                tempFilters['endDate'] = DateTime.now();
                                                tempFilters.remove('customStartDate');
                                                tempFilters.remove('customEndDate');
                                              } else {
                                                tempFilters.remove('timeRange');
                                                tempFilters.remove('startDate');
                                                tempFilters.remove('endDate');
                                              }
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    // Custom Range
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
                                              suffixIcon:   getAdaptiveIcon(iconName: 'calendar_today', defaultIcon: Icons.calendar_today,),
                                            ),
                                            readOnly: true,
                                            controller: TextEditingController(
                                              text: tempFilters['customStartDate'] != null
                                                  ? DateFormat('dd.MM.yyyy').format(tempFilters['customStartDate'])
                                                  : '',
                                            ),
                                            onTap: () async {
                                              final date = await showDatePicker(
                                                context: context,
                                                initialDate: tempFilters['customStartDate'] ?? DateTime.now(),
                                                firstDate: DateTime(2000),
                                                lastDate: DateTime.now(),
                                              );
                                              if (date != null) {
                                                setState(() {
                                                  tempFilters['customStartDate'] = date;
                                                  // Schnellauswahl löschen wenn Custom Range
                                                  tempFilters.remove('timeRange');
                                                  tempFilters.remove('startDate');
                                                  tempFilters.remove('endDate');
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
                                              suffixIcon:     getAdaptiveIcon(iconName: 'calendar_today', defaultIcon: Icons.calendar_today,),
                                            ),
                                            readOnly: true,
                                            controller: TextEditingController(
                                              text: tempFilters['customEndDate'] != null
                                                  ? DateFormat('dd.MM.yyyy').format(tempFilters['customEndDate'])
                                                  : '',
                                            ),
                                            onTap: () async {
                                              final date = await showDatePicker(
                                                context: context,
                                                initialDate: tempFilters['customEndDate'] ?? DateTime.now(),
                                                firstDate: tempFilters['customStartDate'] ?? DateTime(2000),
                                                lastDate: DateTime.now(),
                                              );
                                              if (date != null) {
                                                setState(() {
                                                  tempFilters['customEndDate'] = date;
                                                  tempFilters.remove('timeRange');
                                                  tempFilters.remove('startDate');
                                                  tempFilters.remove('endDate');
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),




                              if (_hasActiveFilters(tempFilters, tempPurposeCodes, tempAdditionalPurpose)) ...[
                                const SizedBox(height: 24),
                                const Divider(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Aktive Filter',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    TextButton.icon(
                                      icon: getAdaptiveIcon(iconName: 'clear_all', defaultIcon: Icons.clear_all,),
                                      label: const Text('Zurücksetzen'),
                                      onPressed: () {
                                        setState(() {
                                          tempFilters.clear();
                                          tempPurposeCodes.clear();
                                          tempAdditionalPurpose.clear();
                                        });
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _buildActiveFilterChips(
                                  tempFilters,
                                  tempPurposeCodes,
                                  tempAdditionalPurpose.text,
                                  setState,
                                ),
                              ],

                            ],
                          ),
                        ),
                      ),
                    ),

                    // Footer mit Aktionsbuttons
                    Container(
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
                            child: const Text('Abbrechen'),
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey[700],
                              side: BorderSide(color: Colors.grey[300]!),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            child: const Text('Anwenden'),
                            onPressed: () {
                              this.setState(() {
                                activeFilters = tempFilters;
                                selectedPurposeCodes = tempPurposeCodes;
                                additionalPurposeController.text = tempAdditionalPurpose.text;
                              });
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F4A29),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ),
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

  // Widget _buildFilterCategory({
  //   required IconData icon,
  //   required String title,
  //   required Widget child,
  // }) {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Row(
  //         children: [
  //           Container(
  //             padding: const EdgeInsets.all(8),
  //             decoration: BoxDecoration(
  //               color: const Color(0xFF0F4A29).withOpacity(0.1),
  //               borderRadius: BorderRadius.circular(8),
  //             ),
  //             child: Icon(icon, color: const Color(0xFF0F4A29)),
  //           ),
  //           const SizedBox(width: 12),
  //           Text(
  //             title,
  //             style: const TextStyle(
  //               fontSize: 16,
  //               fontWeight: FontWeight.bold,
  //               color: Color(0xFF0F4A29),
  //             ),
  //           ),
  //         ],
  //       ),
  //       const SizedBox(height: 12),
  //       child,
  //     ],
  //   );
  // }

  Widget _buildMultiSelectDropdown({
    required String label,
    required List<QueryDocumentSnapshot> options,
    required List<String> selectedValues,
    required Function(List<String>) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: ExpansionTile(
        title: Text(
          selectedValues.isEmpty
              ? label
              : '${selectedValues.length} ausgewählt',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            constraints: const BoxConstraints(maxHeight: 250),
            child: ListView(
              shrinkWrap: true,
              children: options.map((option) {
                final data = option.data() as Map<String, dynamic>;
                final isSelected = selectedValues.contains(option.id);

                return CheckboxListTile(
                  title: Text(data['name'] as String),
                  value: isSelected,
                  onChanged: (bool? checked) {
                    if (checked == true) {
                      onChanged([...selectedValues, option.id]);
                    } else {
                      onChanged(selectedValues.where((id) => id != option.id).toList());
                    }
                  },
                  activeColor: const Color(0xFF0F4A29),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }


// Aktualisierte Methode für die Filter-Chips mit korrekten Namen
  Widget _buildActiveFilterChips(
      Map<String, dynamic> tempFilters,
      List<String> tempPurposeCodes,
      String additionalPurpose,
      StateSetter setState,
      ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Holzart Chips
        if (tempFilters['wood_types'] != null) ...[
          ...tempFilters['wood_types'].map((woodTypeId) {
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('wood_types')
                  .doc(woodTypeId)
                  .get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                final data = snapshot.data!.data() as Map<String, dynamic>;
                return Chip(
                  label: Text('Holzart: ${data['name']}'),
                  deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
                  onDeleted: () {
                    setState(() {
                      final list = List<String>.from(tempFilters['wood_types']);
                      list.remove(woodTypeId);
                      if (list.isEmpty) {
                        tempFilters.remove('wood_types');
                      } else {
                        tempFilters['wood_types'] = list;
                      }
                    });
                  },
                );
              },
            );
          }),
        ],

        // Qualität Chips
        if (activeFilters['qualities'] != null) ...[
          ...activeFilters['qualities'].map((qualityId) {
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('qualities')
                  .doc(qualityId)
                  .get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                final data = snapshot.data!.data() as Map<String, dynamic>;
                return Chip(
                  label: Text('Qualität: ${data['name']}'),
                  deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
                  onDeleted: () {
                    setState(() {
                      final list = List<String>.from(activeFilters['qualities']);
                      list.remove(qualityId);
                      if (list.isEmpty) {
                        activeFilters.remove('qualities');
                      } else {
                        activeFilters['qualities'] = list;
                      }
                    });
                  },
                );
              },
            );
          }),
        ],

        if (activeFilters['timeRange'] != null)
          Chip(
            avatar:
            getAdaptiveIcon(iconName: 'calendar_today', defaultIcon: Icons.calendar_today,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            label: Text(
              'Zeitraum: ${_getTimeRangeText2(activeFilters['timeRange'])}',
            ),
            deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
            onDeleted: () {
              setState(() {
                activeFilters.remove('timeRange');
                activeFilters.remove('startDate');
                activeFilters.remove('endDate');
              });
            },
          ),

        if (activeFilters['customStartDate'] != null && activeFilters['customEndDate'] != null)
          Chip(
            avatar: Icon(
              Icons.date_range,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            label: Text(
              'Zeitraum: ${DateFormat('dd.MM.yyyy').format(activeFilters['customStartDate'])} - ${DateFormat('dd.MM.yyyy').format(activeFilters['customEndDate'])}',
            ),
            deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
            onDeleted: () {
              setState(() {
                activeFilters.remove('customStartDate');
                activeFilters.remove('customEndDate');
              });
            },
          ),
        // Verwendungszweck Chips
        ...selectedPurposeCodes.map((purposeId) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('parts')
                .doc(purposeId)
                .get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              final data = snapshot.data!.data() as Map<String, dynamic>;
              return Chip(
                label: Text('Verwendung: ${data['name']}'),
                deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
                onDeleted: () {
                  setState(() {
                    selectedPurposeCodes.remove(purposeId);
                  });
                },
              );
            },
          );
        }),

        // Weitere Filter-Chips
        if (activeFilters['origin'] != null)
          Chip(
            label: Text('Herkunft: ${activeFilters['origin']}'),
            deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
            onDeleted: () {
              setState(() {
                activeFilters.remove('origin');
              });
            },
          ),

        if (activeFilters['volume_min'] != null)
          Chip(
            label: Text('Min. Volumen: ${activeFilters['volume_min']} m³'),
            deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
            onDeleted: () {
              setState(() {
                activeFilters.remove('volume_min');
              });
            },
          ),

        if (activeFilters['volume_max'] != null)
          Chip(
            label: Text('Max. Volumen: ${activeFilters['volume_max']} m³'),
            deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
            onDeleted: () {
              setState(() {
                activeFilters.remove('volume_max');
              });
            },
          ),

        if (activeFilters['is_moonwood'] == true)
          Chip(
            label: const Text('Nur Mondholz'),
            deleteIcon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close,size: 18),
            onDeleted: () {
              setState(() {
                activeFilters.remove('is_moonwood');
              });
            },
          ),
      ],
    );
  }

  bool _hasActiveFilters(
      Map<String, dynamic> filters,
      List<String> purposeCodes,
      TextEditingController additionalPurpose,
      ) {
    return filters.isNotEmpty ||
        purposeCodes.isNotEmpty ||
        additionalPurpose.text.isNotEmpty;
  }





  void _showEditDialog(String docId, Map<String, dynamic> data) {
    // Erstelle Kopie der Daten für die Bearbeitung
    final editedData = Map<String, dynamic>.from(data);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [

            Text('Rundholz ${data['internal_number']}',style: smallHeadline,),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                // Zeige Bestätigungsdialog
                showDialog(
                  context: context,
                  builder: (BuildContext context) => AlertDialog(
                    title: const Text('Bestätigung'),
                    content: const Text('Wirklich löschen?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Abbruch'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () async {
                          try {
                            // Lösche Dokument aus Firestore
                            await FirebaseFirestore.instance
                                .collection('roundwood')
                                .doc(docId)
                                .delete();

                            if (mounted) {
                              // Schließe beide Dialoge
                              Navigator.pop(context); // Schließt Bestätigungsdialog
                              Navigator.pop(context); // Schließt Hauptdialog

                              AppToast.show(message:'Erfolgreich gelöscht', height: h);


                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Fehler beim Löschen: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Ja',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Identifikation Sektion
                _buildSectionHeader('Identifikation'),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: editedData['internal_number'],
                        decoration: const InputDecoration(
                          labelText: 'Interne Nummer',
                          hintText: 'z.B. 001',
                        ),
                        validator: (value) =>
                        value?.isEmpty ?? true ? 'Pflichtfeld' : null,
                        onChanged: (value) => editedData['internal_number'] = value,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        initialValue: editedData['original_number'],
                        decoration: const InputDecoration(
                          labelText: 'Original Nummer',
                          hintText: 'z.B. 3424',
                        ),
                        onChanged: (value) => editedData['original_number'] = value,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Holz Details Sektion
                _buildSectionHeader('Holz Details'),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('wood_types')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }

                    return DropdownButtonFormField<String>(
                      value: editedData['wood_type'],
                      decoration: const InputDecoration(
                        labelText: 'Holzart',
                      ),
                      items: snapshot.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text(data['name']),
                        );
                      }).toList(),
                      validator: (value) =>
                      value == null ? 'Bitte Holzart wählen' : null,
                      onChanged: (value) {
                        editedData['wood_type'] = value;
                        // Hole den Namen der Holzart
                        final woodType = snapshot.data!.docs
                            .firstWhere((doc) => doc.id == value);
                        editedData['wood_name'] =
                        (woodType.data() as Map<String, dynamic>)['name'];
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('qualities')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }

                    return DropdownButtonFormField<String>(
                      value: editedData['quality'],
                      decoration: const InputDecoration(
                        labelText: 'Qualität',
                      ),
                      items: snapshot.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text(data['name']),
                        );
                      }).toList(),
                      validator: (value) =>
                      value == null ? 'Bitte Qualität wählen' : null,
                      onChanged: (value) {
                        editedData['quality'] = value;
                        // Hole den Namen der Qualität
                        final quality = snapshot.data!.docs
                            .firstWhere((doc) => doc.id == value);
                        editedData['quality_name'] =
                        (quality.data() as Map<String, dynamic>)['name'];
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Maße und Eigenschaften
                _buildSectionHeader('Maße und Eigenschaften'),
                TextFormField(
                  initialValue: editedData['volume']?.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Volumen (m³)',
                    suffixText: 'm³',
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Pflichtfeld';
                    if (double.tryParse(value!) == null) return 'Ungültige Zahl';
                    return null;
                  },
                  onChanged: (value) => editedData['volume'] = double.tryParse(value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: editedData['color'],
                  decoration: const InputDecoration(
                    labelText: 'Farbe',
                    hintText: 'z.B. blau',
                  ),
                  onChanged: (value) => editedData['color'] = value,
                ),
                const SizedBox(height: 16),

                // Herkunft und Verwendung
                _buildSectionHeader('Herkunft und Verwendung'),
                TextFormField(
                  initialValue: editedData['origin'],
                  decoration: const InputDecoration(
                    labelText: 'Herkunft',
                    hintText: 'z.B. Schweiz',
                  ),
                  onChanged: (value) => editedData['origin'] = value,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: editedData['purpose'],
                  decoration: const InputDecoration(
                    labelText: 'Verwendungszweck',
                    hintText: 'z.B. Gitarrendecken',
                  ),
                  onChanged: (value) => editedData['purpose'] = value,
                ),
                const SizedBox(height: 16),

                // Zusätzliche Eigenschaften
                _buildSectionHeader('Zusätzliche Eigenschaften'),
                SwitchListTile(
                  title: const Text('Mondholz'),
                  value: editedData['is_moonwood'] ?? false,
                  onChanged: (value) => setState(() {
                    editedData['is_moonwood'] = value;
                  }),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: editedData['remarks'],
                  decoration: const InputDecoration(
                    labelText: 'Bemerkungen',
                    hintText: 'Zusätzliche Informationen',
                  ),
                  maxLines: 3,
                  onChanged: (value) => editedData['remarks'] = value,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                try {
                  await FirebaseFirestore.instance
                      .collection('roundwood')
                      .doc(docId)
                      .update(editedData);

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Erfolgreich gespeichert'),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
  Future<void> _exportRoundwoodList(String format) async {
    try {
      final roundwoodDocs = await FirebaseFirestore.instance
          .collection('roundwood')
          .get();

      if (format == 'pdf') {
        final pdfBytes = await _generateRoundwoodPdf(roundwoodDocs.docs);
        await _downloadFile(pdfBytes, 'rundholz_liste.pdf', 'application/pdf');
      } else {
        final csvBytes = await _generateRoundwoodCsv(roundwoodDocs.docs);
        await _downloadFile(csvBytes, 'rundholz_liste.csv', 'text/csv');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Export: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Uint8List> _generateRoundwoodCsv(List<QueryDocumentSnapshot> docs) async {
    // Erstelle CSV-Daten
    final List<List<dynamic>> csvData = [
      // Header
      [
        'Interne Nr.',
        'Original Nr.',
        'Holzart',
        'Qualität',
        'Volumen (m³)',
        'Herkunft',
        'Verwendungszweck',
        'Mondholz',
        'Farbe',
        'Bemerkungen',
        'Einschnitts Datum',
      ]
    ];

    // Füge Daten hinzu
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      csvData.add([
        data['internal_number'] ?? '',
        data['original_number'] ?? '',
        data['wood_name'] ?? '',
        data['quality_name'] ?? '',
        data['volume']?.toString() ?? '',
        data['origin'] ?? '',
        data['purpose'] ?? '',
        data['is_moonwood'] == true ? 'Ja' : 'Nein',
        data['color'] ?? '',
        data['remarks'] ?? '',
        data['cutting_date'] != null
            ? DateFormat('dd.MM.yyyy').format((data['cutting_date'] as Timestamp).toDate())
            : '',
      ]);
    }

    // Füge Zusammenfassung hinzu
    csvData.addAll([
      [], // Leerzeile
      ['Zusammenfassung'],
      ['Gesamtanzahl Stämme:', docs.length],
      [
        'Gesamtvolumen (m³):',
        docs.fold<double>(
          0,
              (sum, doc) => sum + ((doc.data() as Map<String, dynamic>)['volume'] as double? ?? 0),
        ).toStringAsFixed(2)
      ],
      [
        'Davon Mondholz:',
        docs.where((doc) => (doc.data() as Map<String, dynamic>)['is_moonwood'] == true).length
      ],
      ['Erstellt am:', DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())],
      if (activeFilters.isNotEmpty) ...[
        ['Aktive Filter:'],
        ...activeFilters.entries.map((e) => [e.key, e.value])
      ],
    ]);

    // Konvertiere zu CSV-String
    final csvString = const ListToCsvConverter().convert(
      csvData,
      fieldDelimiter: ';', // Semikolon für Excel-Kompatibilität
      textDelimiter: '"',
      textEndDelimiter: '"',
    );

    // Füge BOM für Excel-Kompatibilität hinzu
    final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(csvString)];
    return Uint8List.fromList(bytes);
  }
  Future<Uint8List> _generateRoundwoodPdf(List<QueryDocumentSnapshot> docs) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Rundholz Liste',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Erstellt am ${DateFormat('dd.MM.yyyy').format(DateTime.now())}',
                        style: const pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  // Optional: Logo hier einfügen
                ],
              ),
              pw.SizedBox(height: 20),

              // Filter-Info wenn aktiv
              if (activeFilters.isNotEmpty) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Aktive Filter:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 4),
                      ...activeFilters.entries.map((filter) => pw.Text(
                        '${filter.key}: ${filter.value}',
                        style: const pw.TextStyle(fontSize: 10),
                      )),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
              ],

              // Tabelle mit Rundholz-Daten
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1), // Int. Nr.
                  1: const pw.FlexColumnWidth(1), // Orig. Nr.
                  2: const pw.FlexColumnWidth(2), // Holzart
                  3: const pw.FlexColumnWidth(1), // Qualität
                  4: const pw.FlexColumnWidth(1), // Volumen
                  5: const pw.FlexColumnWidth(2), // Herkunft
                  6: const pw.FlexColumnWidth(1), // Mondholz
                },
                children: [
                  // Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      'Int. Nr.',
                      'Orig. Nr.',
                      'Holzart',
                      'Qualität',
                      'Volumen',
                      'Herkunft',
                      'Mondholz',
                    ].map((text) => pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        text,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    )).toList(),
                  ),
                  // Daten
                  ...docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return pw.TableRow(
                      children: [
                        data['internal_number']?.toString() ?? '-',
                        data['original_number']?.toString() ?? '-',
                        data['wood_name']?.toString() ?? '-',
                        data['quality_name']?.toString() ?? '-',
                        '${data['volume']?.toString() ?? '-'} m³',
                        data['origin']?.toString() ?? '-',
                        data['is_moonwood'] == true ? '✓' : '-',
                      ].map((text) => pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(text),
                      )).toList(),
                    );
                  }),
                ],
              ),

              // Zusammenfassung
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Zusammenfassung',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Gesamtanzahl: ${docs.length} Stämme'),
                    pw.Text(
                      'Volumen: ${docs.fold<double>(
                        0,
                            (sum, doc) => sum + ((doc.data() as Map<String, dynamic>)['volume'] as double? ?? 0),
                      ).toStringAsFixed(2)} m³',
                    ),
                    pw.Text(
                      'Mondholz: ${docs.where(
                            (doc) => (doc.data() as Map<String, dynamic>)['is_moonwood'] == true,
                      ).length} Rundholz',
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

  Future<void> _downloadFile(Uint8List bytes, String fileName, String mimeType) async {
    try {
      if (kIsWeb) {
        // Web: HTML download
        final blob = html.Blob([bytes], mimeType);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // Mobile/Desktop: Lokales Speichern
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(bytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Datei gespeichert unter: ${file.path}'),
              action: SnackBarAction(
                label: 'Öffnen',
                onPressed: () async {
                  if (await canLaunchUrl(Uri.file(file.path))) {
                    await launchUrl(Uri.file(file.path));
                  }
                },
              ),
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
  }


  Widget _buildRoundwoodList() {
    return SizedBox(
      height: MediaQuery.of(context).size.height, // Definierte Höhe
      child: Column(
        children: [
          // Filterkopf bleibt gleich
          Container(
            padding: const EdgeInsets.fromLTRB(16,0,16,8),
            child: Row(
              children: [
                Badge(
                  isLabelVisible: activeFilters.isNotEmpty,
                  label: Text(activeFilters.length.toString()),
                  child: IconButton(
                    onPressed: _showFilterDialog,
                      icon:getAdaptiveIcon(iconName: 'filter_list', defaultIcon: Icons.filter_list,),

                    tooltip: 'Filter',
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () async {
                    final pdfBytes = await _generateRoundwoodPdf(
                        await _getFilteredRoundwoodData()
                    );
                    if (mounted) {
                      await _sharePdf(pdfBytes);
                    }
                  },
                  icon:  getAdaptiveIcon(iconName: 'picture_as_pdf', defaultIcon: Icons.picture_as_pdf,),
                  tooltip: 'Als PDF teilen',
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () async {
                    final csvBytes = await _generateRoundwoodCsv(
                        await _getFilteredRoundwoodData()
                    );
                    if (mounted) {
                      await _shareCsv(csvBytes);
                    }
                  },
                  icon:  getAdaptiveIcon(iconName: 'table_chart', defaultIcon: Icons.table_chart, color: Colors.blue),
                  tooltip: 'Als CSV teilen',
                ),
              ],
            ),
          ),

          if (activeFilters.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildActiveFilterChips(
                activeFilters,  // Die aktiven Filter aus dem State
                selectedPurposeCodes,  // Die ausgewählten Verwendungszwecke
                additionalPurposeController.text,  // Der zusätzliche Verwendungszweck
                setState,  // Die setState Funktion der Screen-Klasse
              ),
            ),
          // Liste in Expanded
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getFilteredRoundwoodStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final roundwoods = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: roundwoods.length,
                  itemBuilder: (context, index) {
                    final data = roundwoods[index].data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        onTap: () => _showEditDialog(roundwoods[index].id, data),
                        leading: CircleAvatar(
                          child: Text(data['internal_number'] ?? '-'),
                        ),
                        title: Text(data['wood_name'] ?? 'Unbekannte Holzart'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Qualität: ${data['quality_name'] ?? '-'}'),
                            Text('Herkunft: ${data['origin'] ?? '-'}'),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${data['volume']?.toString() ?? '-'} m³',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (data['is_moonwood'] == true)
                              const Icon(Icons.nightlight, size: 16),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }




// Farbschemata (am Anfang der Klasse definieren)
  final qualityColors = {
    'A': const Color(0xFF2196F3),  // Blau
    'B': const Color(0xFF4CAF50),  // Grün
    'C': const Color(0xFFFFC107),  // Gelb
    'AB': const Color(0xFF1976D2), // Dunkelblau
    'BC': const Color(0xFF388E3C), // Dunkelgrün
  };

  final woodColors = {
    'Fichte': const Color(0xFF8D6E63),    // Braun
    'Tanne': const Color(0xFF795548),     // Dunkelbraun
    'Ahorn': const Color(0xFFBCAAA4),     // Hellbraun
    'Buche': const Color(0xFF6D4C41),     // Mittelbraun
    'Eiche': const Color(0xFF5D4037),     // Sehr dunkelbraun
    'Esche': const Color(0xFFA1887F),     // Graubraun
    'Lärche': const Color(0xFF3E2723),    // Fast schwarz
    'Bergahorn': const Color(0xFFD7CCC8), // Sehr hellbraun
  };

// Hilfsfunktion für Fallback-Farben
  Color getQualityColor(String quality, int index) {
    return qualityColors[quality] ?? Colors.primaries[index % Colors.primaries.length];
  }

  Color getWoodColor(String woodType, int index) {
    return woodColors[woodType] ?? Colors.primaries[index % Colors.primaries.length];
  }

  Widget _buildNavigation() {
    return Column(
      children: _buildNavigationItems(),
    );
  }

  List<Widget> _buildNavigationItems() {
    if (selectedMainSection == 'production') {
      return [
        _buildNavItem('overview', 'Übersicht', Icons.dashboard),
        _buildNavItem('special_wood', 'Spezialholz', Icons.forest),
        _buildNavItem('efficiency', 'Effizienz', Icons.trending_up),
        _buildNavItem('fsc', 'FSC', Icons.eco),
      ];
    }
    if (selectedMainSection == 'roundwood') {
      // Navigation für Rundholz
      return [
        _buildNavItem(
          'list',
          'Liste',
          Icons.format_list_bulleted,
        ),
        _buildNavItem(
          'analysis',
          'Analyse',
          Icons.analytics,
        ),
      ];
    } else {
      // Navigation für Verkauf
      return [
        _buildNavItem(
          'overview',
          'Übersicht',
          Icons.dashboard,
        ),
        _buildNavItem(
          'sales',
          'Verkäufe',
          Icons.point_of_sale,
        ),
        _buildNavItem(
          'inventory',
          'Lagerbestand',
          Icons.inventory,
        ),
        _buildNavItem(
          'customers',
          'Kunden',
          Icons.people,
        ),
        _buildNavItem(
          'trends',
          'Trends',
          Icons.trending_up,
        ),
      ];
    }
  }

  Widget _buildNavItem(String id, String label, IconData icon) {
    final isSelected = selectedTab == id;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: InkWell(
        onTap: () => setState(() => selectedTab = id),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[600],
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[800],
                  fontWeight: isSelected ? FontWeight.bold : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildQualityPieChart(Map<String, int> qualityCount, int totalCount, Map<String, String> filters, ValueNotifier<Map<String, String>> selectedFilters) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sections: qualityCount.entries.map((entry) {
                final percentage = (entry.value / totalCount * 100);
                final color = ChartColors.getQualityColor(
                  entry.key,
                  qualityCount.keys.toList().indexOf(entry.key),
                );

                return PieChartSectionData(
                  value: entry.value.toDouble(),
                  title: percentage > PieChartConfig.minPercentageForLabel
                      ? '${percentage.toStringAsFixed(1)}%'
                      : '',
                  titleStyle: chartTitleStyle,
                  radius: PieChartConfig.radius,
                  color: color,
                  borderSide: const BorderSide(
                    width: 1.5,
                    color: Colors.white,
                  ),
                );
              }).toList(),
              sectionsSpace: PieChartConfig.sectionSpace,
              centerSpaceRadius: PieChartConfig.centerSpaceRadius,
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  if (!event.isInterestedForInteractions ||
                      pieTouchResponse?.touchedSection == null) return;

                  final index = pieTouchResponse!.touchedSection!.touchedSectionIndex;
                  final entry = qualityCount.entries.elementAt(index);
                  selectedFilters.value = {...filters, 'quality': entry.key};
                },
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...qualityCount.entries.map((entry) {
                  final percentage = (entry.value / totalCount * 100);
                  final color = ChartColors.getQualityColor(
                    entry.key,
                    qualityCount.keys.toList().indexOf(entry.key),
                  );

                  return buildLegendItem(
                    entry.key,
                    color,
                    '${percentage.toStringAsFixed(1)}% (${entry.value})',
                  );
                }),
                if (filters.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => selectedFilters.value = {},
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Filter zurücksetzen'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.1),
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildProductionOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI Cards
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            FutureBuilder<Map<String, dynamic>>(  // Geändert von StreamBuilder zu FutureBuilder
              future: ProductionAnalyticsService.getProductionStats(selectedTimeRange),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Fehler: ${snapshot.error}'));
                }

                final stats = snapshot.data ?? {
                  'total_products': 0,
                  'total_batches': 0,
                  'average_batch_size': 0.0,
                  'batch_sizes': <String, int>{},
                };

                return Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Produkte',
                        Text(
                          stats['total_products']?.toString() ?? '0',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icons.inventory,
                        Theme.of(context).colorScheme.primary,
                      iconName:   'inventory',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Chargen',
                        Text(
                          stats['total_batches']?.toString() ?? '0',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icons.layers,
                        Theme.of(context).colorScheme.secondary,
                        iconName:   'layers',
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Expanded(
                    //   child: _buildStatCard(
                    //     'Ø Chargengröße',
                    //     Text(
                    //       (stats['average_batch_size'] as num?)?.toStringAsFixed(1) ?? '0.0',
                    //       style: const TextStyle(
                    //         fontSize: 24,
                    //         fontWeight: FontWeight.bold,
                    //       ),
                    //     ),
                    //     Icons.bar_chart,
                    //     Theme.of(context).colorScheme.tertiary,
                    //   ),
                    // ),
                  ],
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Chargengrößen-Verteilung
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chargengrößen-Verteilung',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  child: FutureBuilder<Map<String, dynamic>>(  // Auch hier FutureBuilder statt StreamBuilder
                    future: ProductionAnalyticsService.getBatchEfficiencyStats(selectedTimeRange),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Fehler: ${snapshot.error}'));
                      }

                      final batchStats = snapshot.data ?? {
                        'batches_by_size': <String, int>{},
                      };

                      final batchSizes = Map<String, int>.from(
                          batchStats['batches_by_size'] as Map<dynamic, dynamic>? ?? {}
                      );

                      if (batchSizes.isEmpty) {
                        return const Center(
                          child: Text('Keine Daten verfügbar'),
                        );
                      }

                      return _buildBatchSizesChart(batchSizes);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

// Hilfsmethode für das Batch-Sizes Chart
  Widget _buildBatchSizesChart(Map<String, int> batchSizes) {
    final maxValue = batchSizes.values.reduce(max).toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue * 1.2,
        barGroups: batchSizes.entries.map((entry) {
          return BarChartGroupData(
            x: batchSizes.keys.toList().indexOf(entry.key),
            barRods: [
              BarChartRodData(
                toY: entry.value.toDouble(),
                color: Theme.of(context).colorScheme.primary,
                width: 20,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final keys = batchSizes.keys.toList();
                if (value < 0 || value >= keys.length) return const SizedBox();
                return Transform.rotate(
                  angle: -0.5,
                  child: Text(
                    keys[value.toInt()],
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
      ),
    );
  }

  Widget _buildSpecialWoodAnalysis() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: Stream.fromFuture(ProductionAnalyticsService.getSpecialWoodStats()),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Spezialholz KPIs
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Haselfichte',
                    '${stats['haselfichte_total']} Produkte',
                    Icons.park,
                    Theme.of(context).colorScheme.secondary,
                    iconName:   'park',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Mondholz',
                    '${stats['moonwood_total']} Produkte',
                    Icons.nightlight,
                    Theme.of(context).colorScheme.tertiary,
                    iconName:   'nighlight',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Verteilung nach Instrumenten
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verteilung nach Instrumenten',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInstrumentDistributionChart(
                      stats['haselfichte_by_instrument'],
                      stats['moonwood_by_instrument'],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductionEfficiency() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: Stream.fromFuture(
          ProductionAnalyticsService.getBatchEfficiencyStats(selectedTimeRange)
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data!;
        // Sicheres Casting der Wochentags-Daten
        final weekdayData = Map<String, int>.from(
            stats['batches_by_weekday'] as Map<dynamic, dynamic>? ?? {}
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Effizienz KPIs
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Durchschnittliche Zeit',
                    Text(
                      '${(stats['avg_time_between_batches'] as num?)?.toStringAsFixed(1) ?? '0'}h',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icons.timer,
                    Theme.of(context).colorScheme.primary,
                    iconName:   'timer',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Chargen gesamt',
                    Text(
                      (stats['total_batches'] as num?)?.toString() ?? '0',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icons.layers,
                    iconName:   'layers',
                    Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Wochentags-Verteilung
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Produktion nach Wochentag',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (weekdayData.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text('Keine Daten verfügbar'),
                        ),
                      )
                    else
                      SizedBox(
                        height: 300,
                        child: _buildWeekdayChart(weekdayData),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWeekdayChart(Map<String, int> weekdayData) {
    final weekdays = [
      'Montag',
      'Dienstag',
      'Mittwoch',
      'Donnerstag',
      'Freitag',
      'Samstag',
      'Sonntag',
    ];

    // Stelle sicher, dass alle Wochentage einen Wert haben
    final normalizedData = Map.fromEntries(
        weekdays.map((day) => MapEntry(day, weekdayData[day] ?? 0))
    );

    final maxValue = normalizedData.values.isEmpty ?
    1.0 : normalizedData.values.reduce(max).toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue * 1.2,
        barGroups: weekdays.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: normalizedData[entry.value]?.toDouble() ?? 0,
                color: Theme.of(context).colorScheme.primary,
                width: 20,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value >= weekdays.length) {
                  return const SizedBox();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    weekdays[value.toInt()].substring(0, 2),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
      ),
    );
  }
  Widget _buildInstrumentDistributionChart(
      Map<String, int> haselfichte,
      Map<String, int> moonwood,
      ) {
    return SizedBox(
      height: 300,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          groupsSpace: 12,
          barGroups: haselfichte.keys.map((instrument) {
            return BarChartGroupData(
              x: haselfichte.keys.toList().indexOf(instrument),
              barRods: [
                BarChartRodData(
                  toY: haselfichte[instrument]?.toDouble() ?? 0,
                  color: Theme.of(context).colorScheme.primary,
                  width: 12,
                ),
                BarChartRodData(
                  toY: moonwood[instrument]?.toDouble() ?? 0,
                  color: Theme.of(context).colorScheme.secondary,
                  width: 12,
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      haselfichte.keys.elementAt(value.toInt()),
                      style: const TextStyle(fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildWoodTypeDistributionChart(Map<String, int> woodTypeData) {
    return SizedBox(
      height: 300,
      child: PieChart(
        PieChartData(
          sections: woodTypeData.entries.map((entry) {
            final total = woodTypeData.values.reduce((a, b) => a + b);
            final percentage = entry.value / total * 100;
            return PieChartSectionData(
              value: entry.value.toDouble(),
              title: percentage >= 5 ? '${percentage.toStringAsFixed(1)}%' : '',
              titleStyle: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              radius: 100,
              color: ChartColors.getWoodColor(entry.key,
                  woodTypeData.keys.toList().indexOf(entry.key)),
              borderSide: const BorderSide(width: 1, color: Colors.white),
            );
          }).toList(),
          sectionsSpace: 2,
          centerSpaceRadius: 40,
        ),
      ),
    );
  }

// Neue Chart-Komponente für Chargenanalyse
  Widget _buildBatchAnalysisChart(List<Map<String, dynamic>> batchData) {
    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 5,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= batchData.length) return const SizedBox();
                  final date = batchData[value.toInt()]['date'] as DateTime;
                  return Transform.rotate(
                    angle: -0.5,
                    child: Text(
                      DateFormat('dd.MM').format(date),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            // Chargengröße
            LineChartBarData(
              spots: List.generate(batchData.length, (index) {
                return FlSpot(
                  index.toDouble(),
                  (batchData[index]['quantity'] as int).toDouble(),
                );
              }),
              isCurved: true,
              color: Theme.of(context).colorScheme.primary,
              barWidth: 2,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

// KPI Card Builder für Produktionsanalysen
  Widget _buildProductionKpiCard(String title, String value, String subtitle, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

// Hilfsmethode für die Trend-Anzeige
  Widget _buildTrendIndicator(double change) {
    final isPositive = change >= 0;
    final color = isPositive ? Colors.green : Colors.red;
    final icon = isPositive ? Icons.trending_up : Icons.trending_down;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          '${change.abs().toStringAsFixed(1)}%',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

// Legend Builder für Charts
  Widget _buildChartLegend(Map<String, Color> items) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: items.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: entry.value,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 1,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                entry.key,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFSCAnalysis() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: Stream.fromFuture(ProductionAnalyticsService.getFSCStats()),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatCard(
              'FSC 100% Produkte',
              stats['fsc_total'].toString(),
              Icons.eco,
              Theme.of(context).colorScheme.primary,
              iconName:   'eco',
            ),
            const SizedBox(height: 24),

            // FSC Verteilung nach Holzart
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FSC Verteilung nach Holzart',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildWoodTypeDistributionChart(stats['fsc_by_wood_type']),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }



  Widget _buildSelectedContent() {
    if (selectedMainSection == 'production') {
      switch (selectedTab) {
        case 'overview':
          return _buildProductionOverview();
        case 'special_wood':
          return _buildSpecialWoodAnalysis();
        case 'efficiency':
          return _buildProductionEfficiency();
        case 'fsc':
          return _buildFSCAnalysis();
        default:
          return _buildProductionOverview();
      }
    }
    // Content basierend auf Hauptbereich und ausgewähltem Tab
    if (selectedMainSection == 'roundwood') {
      switch (selectedTab) {
        case 'list':
          return _buildRoundwoodList();
        case 'analysis':
          return _buildRoundwoodSection();
        default:
          return _buildRoundwoodList();
      }
    } else {
      // Verkaufsbereich
      switch (selectedTab) {
        case 'overview':
          return _buildOverviewSection();
        case 'sales':
          return _buildSalesSection();
        case 'inventory':
          return _buildInventorySection();
        case 'customers':
          return _buildCustomersSection();
        case 'trends':
          return _buildTrendsSection();
        default:
          return _buildOverviewSection();
      }
    }
  }
  Widget _buildRoundwoodSection() {
    // State für ausgewählte Filter
    final selectedFilters = ValueNotifier<Map<String, String>>({});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
      // KPI Cards in einer kompakteren Row
      SizedBox(
      height: 120, // Reduzierte Höhe
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: _getFilteredRoundwoodStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              double totalVolume = 0;
              int totalLogs = snapshot.data!.docs.length;
              int moonwoodCount = 0;

              for (var doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final volume = data['volume'];
                if (volume != null) {
                  totalVolume += volume as double;
                }
                if (data['is_moonwood'] == true) {
                  moonwoodCount++;
                }
              }

              return Row(
                children: [
                  _buildCompactStatCard(
                    'Volumen',
                    '${totalVolume.toStringAsFixed(2)} m³',
                    Icons.straighten,
                    Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  _buildCompactStatCard(
                    'Holzlisten',
                    totalLogs.toString(),
                    Icons.forest,
                    Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  _buildCompactStatCard(
                    'Mondholz',
                    '${(moonwoodCount / totalLogs * 100).toStringAsFixed(1)}%',
                    Icons.nightlight,
                    Theme.of(context).colorScheme.tertiary,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),

    // Verbesserter Volumen-Trend
    Card(
    child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Row(
    children: [
    const Text(
    'Volumen-Entwicklung',
    style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    ),
    ),
    const Spacer(),
    _buildChartLegend2(),
    ],
    ),
    const SizedBox(height: 16),
    SizedBox(
    height: 300,
    child: StreamBuilder<QuerySnapshot>(
    stream: _getFilteredRoundwoodStream(),
    builder: (context, snapshot) {
    if (!snapshot.hasData) {
    return const Center(child: CircularProgressIndicator());
    }

    // Verbesserte Datumsgruppierung
    final volumeByDate = <DateTime, double>{};
    double maxVolume = 0;

    for (var doc in snapshot.data!.docs) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['timestamp'] as Timestamp;
    final date = DateTime(
    timestamp.toDate().year,
    timestamp.toDate().month,
    timestamp.toDate().day,
    );
    final volume = data['volume'] as double? ?? 0;
    volumeByDate[date] = (volumeByDate[date] ?? 0) + volume;
    maxVolume = math.max(maxVolume, volumeByDate[date]!);
    }

    if (volumeByDate.isEmpty) {
    return const Center(
    child: Text('Keine Daten für den ausgewählten Zeitraum'),
    );
    }

    final sortedEntries = volumeByDate.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));

    // Kumulatives Volumen
    double runningTotal = 0;
    final cumulativeVolume = sortedEntries.map((entry) {
    runningTotal += entry.value;
    return MapEntry(entry.key, runningTotal);
    }).toList();

    return LineChart(
    LineChartData(
    gridData: FlGridData(
    show: true,
    drawVerticalLine: false,
    horizontalInterval: maxVolume / 5,
    getDrawingHorizontalLine: (value) => FlLine(
    color: Colors.grey.withOpacity(0.2),
    strokeWidth: 1,
    ),
    ),
    titlesData: FlTitlesData(
    leftTitles: AxisTitles(
    sideTitles: SideTitles(
    showTitles: true,
    reservedSize: 60,
    interval: maxVolume / 5,
    getTitlesWidget: (value, meta) {
    return Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Text(
    '${value.toStringAsFixed(1)} m³',
    style: TextStyle(
    fontSize: 10,
    color: Colors.grey[600],
    ),
    ),
    );
    },
    ),
    ),
    bottomTitles: AxisTitles(
    sideTitles: SideTitles(
    showTitles: true,
    interval: 30 * 24 * 60 * 60 * 1000,
    getTitlesWidget: (value, meta) {
    final date = DateTime.fromMillisecondsSinceEpoch(
    value.toInt());
    return Transform.rotate(
    angle: -0.5,
    child: Text(
    DateFormat('MM.yyyy').format(date),
    style: TextStyle(
    fontSize: 10,
    color: Colors.grey[600],
    ),
    ),
    );
    },
    ),
    ),
    rightTitles: const AxisTitles(
    sideTitles: SideTitles(showTitles: false),
    ),
    topTitles: const AxisTitles(
    sideTitles: SideTitles(showTitles: false),
    ),
    ),
    borderData: FlBorderData(show: false),
    lineBarsData: [
    // Tägliches Volumen
    LineChartBarData(
    spots: sortedEntries.map((entry) {
    return FlSpot(
    entry.key.millisecondsSinceEpoch.toDouble(),
    entry.value,
    );
    }).toList(),
    isCurved: true,
    color: Theme.of(context).colorScheme.secondary,
    barWidth: 2,
    dotData: FlDotData(
    show: true,
    getDotPainter: (spot, percent, bar, index) {
    return FlDotCirclePainter(
    radius: 3,
    color: Theme.of(context).colorScheme.secondary,
    strokeWidth: 1,
    strokeColor: Colors.white,
    );
    },
    ),
    ),
    // Kumulierte Linie
    LineChartBarData(
    spots: cumulativeVolume.map((entry) {
    return FlSpot(
    entry.key.millisecondsSinceEpoch.toDouble(),
    entry.value,
    );
    }).toList(),
    isCurved: true,
    color: Theme.of(context).colorScheme.primary,
    barWidth: 2,
    dotData: const FlDotData(show: false),
    belowBarData: BarAreaData(
    show: true,
    color: Theme.of(context)
        .colorScheme
        .primary
        .withOpacity(0.1),
    ),
    ),
    ],
    ),
    );
    },
    ),
    ),
    ],
    ),
    ),
    ),
    const SizedBox(height: 24),

    // Verteilungs-Charts untereinander
    ValueListenableBuilder<Map<String, String>>(
    valueListenable: selectedFilters,
    builder: (context, filters, _) {
    return Column(
    children: [
    // Qualitätsverteilung
    Card(
    child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    const Text(
    'Qualitätsverteilung',
    style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    ),
    ),
    const SizedBox(height: 16),
    SizedBox(
    height: 300,
    child: StreamBuilder<QuerySnapshot>(
    stream: _getFilteredRoundwoodStream(),
    builder: (context, snapshot) {
    if (!snapshot.hasData) {
    return const Center(
    child: CircularProgressIndicator());
    }

    final qualityCount = <String, int>{};
    for (var doc in snapshot.data!.docs) {
    final data = doc.data() as Map<String, dynamic>;
    if (filters['wood_type'] != null &&
    data['wood_type'] != filters['wood_type']) {
    continue;
    }
    final quality = data['quality_name'] as String;
    qualityCount[quality] =
    (qualityCount[quality] ?? 0) + 1;
    }

    return buildQualityPieChart(
      qualityCount,
      snapshot.data!.docs.length,
      filters,
      selectedFilters,
    );

    },
    ),
    ),
    ],
    ),
    ),
    ),
    const SizedBox(height: 16),

    // Holzartenverteilung
    Card(
    child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    const Text(
    'Holzartenverteilung',
    style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    ),
    ),
    const SizedBox(height: 16),
    SizedBox(
    height: 300,
    child: StreamBuilder<QuerySnapshot>(
    stream: _getFilteredRoundwoodStream(),
    builder: (context, snapshot) {
    if (!snapshot.hasData) {
    return const Center(
    child: CircularProgressIndicator());
    }

    final woodTypeCount = <String, int>{};
    for (var doc in snapshot.data!.docs) {
    final data = doc.data() as Map<String, dynamic>;
    if (filters['quality'] != null &&
    data['quality_name'] != filters['quality']) {
    continue;
    }
    final woodType = data['wood_name'] as String;
    woodTypeCount[woodType] =
    (woodTypeCount[woodType] ?? 0) + 1;
    }

    // Holzartenverteilung
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sections: woodTypeCount.entries.map((entry) {
                final percentage = entry.value / snapshot.data!.docs.length * 100;
                final color = getWoodColor(entry.key, woodTypeCount.keys.toList().indexOf(entry.key));
                return PieChartSectionData(
                  value: entry.value.toDouble(),
                  title: percentage > 5 ? '${percentage.toStringAsFixed(1)}%' : '',
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  radius: 100,
                  color: color,
                  borderSide: const BorderSide(width: 1, color: Colors.white),
                );
              }).toList(),
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  if (!event.isInterestedForInteractions ||
                      pieTouchResponse == null ||
                      pieTouchResponse.touchedSection == null) {
                    return;
                  }
                  final index = pieTouchResponse.touchedSection!.touchedSectionIndex;
                  final entry = woodTypeCount.entries.elementAt(index);
                  selectedFilters.value = {
                    ...filters,
                    'wood_type': entry.key,  // Hier war der Fehler: 'quality' -> 'wood_type'
                  };
                },
              ),
            ),
          ),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...woodTypeCount.entries.map((entry) {
                final percentage = entry.value / snapshot.data!.docs.length * 100;
                final color = getWoodColor(entry.key, woodTypeCount.keys.toList().indexOf(entry.key));
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${entry.key}: ${percentage.toStringAsFixed(1)}% (${entry.value})',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (filters.isNotEmpty) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    selectedFilters.value = {};
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Filter zurücksetzen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.1),
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
    },
    ),
    ),
    ],
    ),
    ),
    ),
    ],
    );
    },
    ),


      ],
    );
  }

// Neue kompakte Statistik-Karte
  Widget _buildCompactStatCard(
      String title,
      String value,
      IconData icon,
      Color color,
      ) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.1),
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

// Chart Legende
  Widget _buildChartLegend2() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        const Text(
          'Kumuliert',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(width: 12),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        const Text(
          'Täglich',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Stream<QuerySnapshot> _getFilteredRoundwoodStream() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('roundwood');

    // Zeitraum Filter
    if (activeFilters['timeRange'] != null) {
      DateTime startDate;
      switch (activeFilters['timeRange']) {
        case 'week':
          startDate = DateTime.now().subtract(const Duration(days: 7));
          break;
        case 'month':
          startDate = DateTime.now().subtract(const Duration(days: 30));
          break;
        case 'quarter':
          startDate = DateTime.now().subtract(const Duration(days: 90));
          break;
        case 'year':
          startDate = DateTime.now().subtract(const Duration(days: 365));
          break;
        default:
          startDate = DateTime.now().subtract(const Duration(days: 30));
      }
      query = query.where('timestamp', isGreaterThan: startDate);
    } else if (activeFilters['customStartDate'] != null && activeFilters['customEndDate'] != null) {
      query = query.where('timestamp',
          isGreaterThanOrEqualTo: activeFilters['customStartDate'],
          isLessThanOrEqualTo: activeFilters['customEndDate']
      );
    }

    // Holzart Filter
    if (activeFilters['wood_types'] != null && activeFilters['wood_types'].isNotEmpty) {
      final woodTypes = List<String>.from(activeFilters['wood_types']);
      query = query.where('wood_type', whereIn: woodTypes);
    }

    // Qualität Filter
    if (activeFilters['qualities'] != null && activeFilters['qualities'].isNotEmpty) {
      final qualities = List<String>.from(activeFilters['qualities']);
      query = query.where('quality', whereIn: qualities);
    }

    // Verwendungszweck Filter
    if (selectedPurposeCodes.isNotEmpty) {
      query = query.where('purpose_codes', arrayContainsAny: selectedPurposeCodes);
    }

    // Zusätzlicher Verwendungszweck
    if (additionalPurposeController.text.isNotEmpty) {
      query = query.where('additional_purpose', isEqualTo: additionalPurposeController.text);
    }

    // Herkunft Filter
    if (activeFilters['origin'] != null && activeFilters['origin'].isNotEmpty) {
      query = query.where('origin', isEqualTo: activeFilters['origin']);
    }

    // Mondholz Filter
    if (activeFilters['is_moonwood'] == true) {
      query = query.where('is_moonwood', isEqualTo: true);
    }

    // Volumen Filter
    if (activeFilters['volume_min'] != null) {
      query = query.where('volume', isGreaterThanOrEqualTo: activeFilters['volume_min']);
    }
    if (activeFilters['volume_max'] != null) {
      query = query.where('volume', isLessThanOrEqualTo: activeFilters['volume_max']);
    }

    return query.orderBy('timestamp', descending: true).snapshots();
  }
























  Widget _buildOverviewSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildKpiSection(),
        Wrap( // Wrap statt Row für bessere Responsivität
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 320, // Fixe Breite für konsistentes Layout
              child: _buildStatCard(
                'Gesamtumsatz',
                StreamBuilder<QuerySnapshot>(
                  stream: _getSalesStream(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }

                    double total = 0;
                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final calculations = data['calculations'] as Map<String, dynamic>;
                      total += calculations['total'] as double;
                    }

                    return Text(NumberFormat.currency(
                      locale: 'de_CH',
                      symbol: 'CHF',
                    ).format(total));
                  },
                ),
                Icons.attach_money,
                iconName:   'attach_money',
                colorScheme.primary,
                subtitle: 'Gesamter Zeitraum',
              ),
            ),
            SizedBox(
              width: 320,
              child: _buildStatCard(
                'Anzahl Verkäufe',
                StreamBuilder<QuerySnapshot>(
                  stream: _getSalesStream(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    return Text('${snapshot.data!.docs.length}');
                  },
                ),
                Icons.shopping_cart,
                iconName:   'shopping_cart',

                colorScheme.secondary,
                subtitle: 'Abgeschlossene Bestellungen',
              ),
            ),
            SizedBox(
              width: 320,
              child: _buildStatCard(
                'Ø Bestellwert',
                StreamBuilder<QuerySnapshot>(
                  stream: _getSalesStream(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }

                    double total = 0;
                    final count = snapshot.data!.docs.length;

                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final calculations = data['calculations'] as Map<String, dynamic>;
                      total += calculations['total'] as double;
                    }

                    final average = count > 0 ? total / count : 0;

                    return Text(NumberFormat.currency(
                      locale: 'de_CH',
                      symbol: 'CHF',
                    ).format(average));
                  },
                ),
                Icons.analytics,
                iconName:   'analytics',
                colorScheme.tertiary,
                subtitle: 'Pro Bestellung',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Verbesserte Verkaufstrend-Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verkaufstrend',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Entwicklung der Verkäufe über Zeit',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 300,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _getSalesStream(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final salesByDate = <DateTime, double>{};
                      for (var doc in snapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final timestamp = data['metadata']['timestamp'] as Timestamp;
                        final date = DateTime(
                          timestamp.toDate().year,
                          timestamp.toDate().month,
                          timestamp.toDate().day,
                        );
                        final calculations = data['calculations'] as Map<String, dynamic>;
                        final total = calculations['total'] as double;

                        salesByDate[date] = (salesByDate[date] ?? 0) + total;
                      }

                      final spots = salesByDate.entries.map((entry) {
                        return FlSpot(
                          entry.key.millisecondsSinceEpoch.toDouble(),
                          entry.value,
                        );
                      }).toList();

                      return LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 1000,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: colorScheme.outlineVariant,
                                strokeWidth: 1,
                              );
                            },
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 60,
                                getTitlesWidget: (value, meta) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Text(
                                      NumberFormat.currency(
                                        locale: 'de_CH',
                                        symbol: 'CHF',
                                        decimalDigits: 0,
                                      ).format(value),
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                interval: 86400000 * 7, // 7 Tage Interval
                                getTitlesWidget: (value, meta) {
                                  final date = DateTime.fromMillisecondsSinceEpoch(
                                    value.toInt(),
                                  );
                                  return Transform.rotate(
                                    angle: -0.5, // Schräge Datumsanzeige
                                    child: Text(
                                      DateFormat('dd.MM').format(date),
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              color: colorScheme.primary,
                              barWidth: 3,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, bar, index) {
                                  return FlDotCirclePainter(
                                    radius: 4,
                                    color: colorScheme.primary,
                                    strokeWidth: 2,
                                    strokeColor: colorScheme.surface,
                                  );
                                },
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                color: colorScheme.primary.withOpacity(0.1),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title,
      dynamic value,
      IconData icon,
      Color color,
      {String? subtitle,
        String? iconName} // Neuer Parameter für adaptiveIcon
      ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(
              red: 0,
              green:0,
              blue: 0,
              alpha: 0.1
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(
                        red: 0,
                        green: 0,
                        blue: 0,
                        alpha: 0.1
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: iconName != null
                      ? getAdaptiveIcon(
                    iconName: iconName,
                    defaultIcon: icon,
                    color: color,
                    size: 20,
                  )
                      : Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (value is Widget)
              value
            else
              Text(
                value.toString(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInventorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Aktuelle Lagerbestandsübersicht
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aktuelle Lagerbestände',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('inventory')
                      .orderBy('quantity')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final items = snapshot.data!.docs;

                    // Berechne kritische Bestände
                    final lowStock = items.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return (data['quantity'] as int) < 10; // Schwellenwert
                    }).length;

                    return Column(
                      children: [
                        // Bestandsübersicht Stats
                        Row(
                          children: [
                            Expanded(
                              child: _buildInventoryStatCard(
                                'Gesamt',
                                items.length.toString(),
                                Icons.inventory,
                                Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildInventoryStatCard(
                                'Kritischer',
                                lowStock.toString(),
                                Icons.warning,
                                Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Bestandsliste mit Warnungen
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final data = items[index].data() as Map<String, dynamic>;
                            final quantity = data['quantity'] as int;
                            final isLowStock = quantity < 10;

                            return ListTile(
                              title: Text(data['product_name'] as String),
                              subtitle: Text(
                                '''${data['instrument_name']} - ${data['part_name']}
${data['wood_name']} - ${data['quality_name']}''',
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isLowStock
                                      ? Colors.red.withOpacity(0.1)
                                      : Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '$quantity ${data['unit']}',
                                  style: TextStyle(
                                    color: isLowStock ? Colors.red : Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Wareneingangsanalyse
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Wareneingänge',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('stock_entries')
                      .where('type', isEqualTo: 'entry')
                      .orderBy('timestamp', descending: true)
                      .limit(50)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final data = snapshot.data!.docs[index].data()
                        as Map<String, dynamic>;
                        final timestamp = data['timestamp'] as Timestamp;

                        return ListTile(
                          title: Text(data['product_name'] as String),
                          subtitle: Text(
                            DateFormat('dd.MM.yyyy HH:mm').format(
                                timestamp.toDate()
                            ),
                          ),
                          trailing: Text(
                            '+${data['quantity_change']}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kundenübersicht
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kundenanalyse',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot>(
                  stream: _getSalesStream(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Kundenanalyse
                    final customerStats = <String, Map<String, dynamic>>{};
                    var totalSales = 0.0;

                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final customer = data['customer'] as Map<String, dynamic>;
                      final customerId = customer['id'] as String;
                      final calculations = data['calculations'] as Map<String, dynamic>;
                      final total = calculations['total'] as double;

                      totalSales += total;

                      if (!customerStats.containsKey(customerId)) {
                        customerStats[customerId] = {
                          'customer': customer,
                          'orders': 0,
                          'total': 0.0,
                          'items': 0,
                          'lastOrder': null as DateTime?,
                        };
                      }

                      customerStats[customerId]!['orders']++;
                      customerStats[customerId]!['total'] += total;

                      // Zähle Artikel
                      final items = data['items'] as List;
                      customerStats[customerId]!['items'] += items.length;

                      // Prüfe letzten Einkauf
                      final timestamp = (data['metadata']['timestamp'] as Timestamp).toDate();
                      final lastOrder = customerStats[customerId]!['lastOrder'] as DateTime?;
                      if (lastOrder == null || timestamp.isAfter(lastOrder)) {
                        customerStats[customerId]!['lastOrder'] = timestamp;
                      }
                    }

                    // Sortiere nach Umsatz
                    final sortedCustomers = customerStats.entries.toList()
                      ..sort((a, b) => (b.value['total'] as double)
                          .compareTo(a.value['total'] as double));

                    return Column(
                      children: [
                        // Kundenstatistiken
                        Row(
                          children: [
                            Expanded(
                              child: _buildCustomerStatCard(
                                'Aktive Kunden',
                                'Kommt noch',
                                Icons.people,
                                Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildCustomerStatCard(
                                'Ø Bestellwert',
                                NumberFormat.currency(
                                  decimalDigits: 0,
                                  locale: 'de_CH',
                                  symbol: 'CHF',
                                ).format(totalSales / snapshot.data!.docs.length),
                                 Icons.shopping_cart,
                                iconName:   'shopping_cart',
                    Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Kundenliste mit Details
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: sortedCustomers.length,
                          itemBuilder: (context, index) {
                            final customerData = sortedCustomers[index].value;
                            final customer = customerData['customer'] as Map<String, dynamic>;
                            final lastOrder = customerData['lastOrder'] as DateTime;

                            return ExpansionTile(
                              title: Text(customer['company'] as String),
                              subtitle: Text(
                                '''${customerData['orders']} Bestellungen
Letzter Einkauf: ${DateFormat('dd.MM.yyyy').format(lastOrder)}''',
                              ),
                              trailing: Text(
                                NumberFormat.currency(
                                  locale: 'de_CH',
                                  symbol: 'CHF',
                                ).format(customerData['total']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Kontakt: ${customer['fullName']}'),
                                      Text('Email: ${customer['email']}'),
                                      Text('Adresse: ${customer['street']} ${customer['houseNumber']}'),
                                      Text('${customer['zipCode']} ${customer['city']}'),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Durchschnittlicher Bestellwert: ${NumberFormat.currency(
                                          locale: 'de_CH',
                                          symbol: 'CHF',
                                        ).format(customerData['total'] / customerData['orders'])}',
                                      ),
                                      Text(
                                        'Artikel pro Bestellung: ${(customerData['items'] / customerData['orders']).toStringAsFixed(1)}',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrendsSection() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
    // Saisonale Analyse
    Card(
    child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    const Text(
    'Saisonale Trends',
    style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    ),
    ),
    const SizedBox(height: 16),
    StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('sales_receipts')
        .orderBy('metadata.timestamp', descending: true)
        .limit(365) // Letztes Jahr
        .snapshots(),
    builder: (context, snapshot) {
    if (!snapshot.hasData) {
    return const Center(child: CircularProgressIndicator());
    }

    // Gruppiere nach Monat
    final monthlySales = <int, double>{};
    final monthlyItems = <int, int>{};

    for (var doc in snapshot.data!.docs) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['metadata']['timestamp'] as Timestamp;
    final month = timestamp.toDate().month;
    final calculations = data['calculations'] as Map<String, dynamic>;
    final total = calculations['total'] as double;
    final items = (data['items'] as List).length;

    monthlySales[month] = (monthlySales[month] ?? 0) + total;
    monthlyItems[month] = (monthlyItems[month] ?? 0) + items;
    }

    // Erstelle Datenpunkte für Chart
    final spots = List.generate(12, (index) {
    final month = index + 1;
    return [
    FlSpot(
    index.toDouble(),
    monthlySales[month] ?? 0,
    ),
    FlSpot(
    index.toDouble(),
    (monthlyItems[month] ?? 0).toDouble(),
    ),
    ];
    });

    return SizedBox(
    height: 300,
    child: LineChart(
    LineChartData(
    gridData: FlGridData(show: true),
    titlesData: FlTitlesData(
    leftTitles: AxisTitles(
    sideTitles: SideTitles(
    showTitles: true,
    reservedSize: 40,
    getTitlesWidget: (value, meta) {
    return Text(
    NumberFormat.compact().format(value),
    style: const TextStyle(fontSize: 10),
    );
    },
    ),
    ),
    rightTitles: AxisTitles(
    sideTitles: SideTitles(
    showTitles: true,
    reservedSize: 40,
    getTitlesWidget: (value, meta) {
    return Text(
    value.toInt().toString(),
    style: const TextStyle(fontSize: 10),
    );
    },
    ),
    ),
    bottomTitles: AxisTitles(
    sideTitles: SideTitles(
    showTitles: true,
    getTitlesWidget: (value, meta) {
    if (value.toInt() >= 0 && value.toInt() < 12) {
    return Text(
    DateFormat('MMM').format(
    DateTime(2024, value.toInt() + 1),
    ),
    style: const TextStyle(fontSize: 10),
    );
    }
    return const SizedBox();
    },
    ),
    ),
    ),
      borderData: FlBorderData(show: true),
      lineBarsData: [
        // Umsatz
        LineChartBarData(
          spots: spots.map((s) => s[0]).toList(),
          isCurved: true,
          color: Colors.green,
          barWidth: 2,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.green.withOpacity(0.1),
          ),
        ),
        // Artikelanzahl
        LineChartBarData(
          spots: spots.map((s) => s[1]).toList(),
          isCurved: true,
          color: Colors.blue,
          barWidth: 2,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.blue.withOpacity(0.1),
          ),
        ),
      ],
    ),
    ),
    );
    },
    ),
      const SizedBox(height: 8),
      // Legende
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem('Umsatz', Colors.green),
          const SizedBox(width: 24),
          _buildLegendItem('Verkaufte Artikel', Colors.blue),
        ],
      ),
    ],
    ),
    ),
    ),
          const SizedBox(height: 24),

          // Messeanalyse
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Messeverkäufe',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('sales_receipts')
                        .where('metadata.fairId', isNull: false)
                        .orderBy('metadata.timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      // Gruppiere nach Messe
                      final fairStats = <String, Map<String, dynamic>>{};

                      for (var doc in snapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final fair = data['fair'] as Map<String, dynamic>?;
                        if (fair == null) continue;

                        final fairId = fair['id'] as String;
                        final calculations = data['calculations'] as Map<String, dynamic>;
                        final total = calculations['total'] as double;

                        if (!fairStats.containsKey(fairId)) {
                          fairStats[fairId] = {
                            'fair': fair,
                            'orders': 0,
                            'total': 0.0,
                            'items': 0,
                            'customers': <String>{},
                          };
                        }

                        fairStats[fairId]!['orders']++;
                        fairStats[fairId]!['total'] += total;
                        fairStats[fairId]!['items'] += (data['items'] as List).length;
                        fairStats[fairId]!['customers'].add(
                            (data['customer'] as Map<String, dynamic>)['id'] as String
                        );
                      }

                      // Sortiere nach Umsatz
                      final sortedFairs = fairStats.entries.toList()
                        ..sort((a, b) => (b.value['total'] as double)
                            .compareTo(a.value['total'] as double));

                      return Column(
                        children: [
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: sortedFairs.length,
                            itemBuilder: (context, index) {
                              final fairData = sortedFairs[index].value;
                              final fair = fairData['fair'] as Map<String, dynamic>;
                              final customers = fairData['customers'] as Set<String>;

                              return ExpansionTile(
                                title: Text(fair['name'] as String),
                                subtitle: Text(
                                  '''${fair['city']}, ${fair['country']}
${fairData['orders']} Bestellungen, ${customers.length} Kunden''',
                                ),
                                trailing: Text(
                                  NumberFormat.currency(
                                    locale: 'de_CH',
                                    symbol: 'CHF',
                                  ).format(fairData['total']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Datum: ${DateFormat('dd.MM.yyyy').format(
                                            DateTime.parse(fair['startDate'] as String)
                                        )} - ${DateFormat('dd.MM.yyyy').format(
                                            DateTime.parse(fair['endDate'] as String)
                                        )}'),
                                        Text(
                                          'Durchschnittlicher Bestellwert: ${NumberFormat.currency(
                                            locale: 'de_CH',
                                            symbol: 'CHF',
                                          ).format(fairData['total'] / fairData['orders'])}',
                                        ),
                                        Text(
                                          'Artikel pro Bestellung: ${(fairData['items'] / fairData['orders']).toStringAsFixed(1)}',
                                        ),
                                        Text(
                                          'Umsatz pro Kunde: ${NumberFormat.currency(
                                            locale: 'de_CH',
                                            symbol: 'CHF',
                                          ).format(fairData['total'] / customers.length)}',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Produkt-Trends
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Produkttrends',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
//                   StreamBuilder<QuerySnapshot>(
//                     stream: _getSalesStream(),
//                     builder: (context, snapshot) {
//                       if (!snapshot.hasData) {
//                         return const Center(child: CircularProgressIndicator());
//                       }
//
//                       // Analysiere Produktverkäufe über Zeit
//                       final productTrends = <String, List<Map<String, dynamic>>>{};
//
//                       for (var doc in snapshot.data!.docs) {
//                         final data = doc.data() as Map<String, dynamic>;
//                         final timestamp = (data['metadata']['timestamp'] as Timestamp).toDate();
//                         final items = data['items'] as List;
//
//                         for (var item in items) {
//                           final productId = item['product_id'] as String;
//                           if (!productTrends.containsKey(productId)) {
//                             productTrends[productId] = [];
//                           }
//
//                           productTrends[productId]!.add({
//                             'date': timestamp,
//                             'quantity': item['quantity'] as int,
//                             'total': item['total'] as double,
//                             'name': item['product_name'] as String,
//                           });
//                         }
//                       }
//
//                       // Berechne Trends
//                       final trends = productTrends.entries.map((entry) {
//                         final sales = entry.value;
//                         sales.sort((a, b) => a['date'].compareTo(b['date']));
//
//                         // Berechne Wachstumsrate
//                         var growth = 0.0;
//                         if (sales.length > 1) {
//                           final firstWeekSales = sales.take(7).fold<double>(
//                               0, (sum, item) => sum + (item['total'] as double)
//                           );
//                           final lastWeekSales = sales.skip(sales.length - 7).fold<double>(
//                               0, (sum, item) => sum + (item['total'] as double)
//                           );
//
//                           if (firstWeekSales > 0) {
//                             growth = ((lastWeekSales - firstWeekSales) / firstWeekSales) * 100;
//                           }
//                         }
//
//                         return MapEntry(
//                           entry.key,
//                           {
//                             'name': sales.first['name'],
//                             'totalSales': sales.fold<double>(
//                                 0, (sum, item) => sum + (item['total'] as double)
//                             ),
//                             'totalQuantity': sales.fold<int>(
//                                 0, (sum, item) => sum + (item['quantity'] as int)
//                             ),
//                             'growth': growth,
//                           },
//                         );
//                       }).toList()
//                         ..sort((a, b) => b.value['growth'].compareTo(a.value['growth']));
//
//                       return Column(
//                         children: [
//                           ...trends.take(10).map((trend) {
//                             final isPositiveGrowth = trend.value['growth'] > 0;
//                             return ListTile(
//                               title: Text(trend.value['name'] as String),
//                               subtitle: Text(
//                                 '''Verkaufte Menge: ${trend.value['totalQuantity']}
// Umsatz: ${NumberFormat.currency(
//                                   locale: 'de_CH',
//                                   symbol: 'CHF',
//                                 ).format(trend.value['totalSales'])}''',
//                               ),
//                               trailing: Row(
//                                 mainAxisSize: MainAxisSize.min,
//                                 children: [
//                                   Icon(
//                                     isPositiveGrowth
//                                         ? Icons.trending_up
//                                         : Icons.trending_down,
//                                     color: isPositiveGrowth
//                                         ? Colors.green
//                                         : Colors.red,
//                                   ),
//                                   const SizedBox(width: 8),
//                                   Text(
//                                     '${trend.value['growth'].toStringAsFixed(1)}%',
//                                     style: TextStyle(
//                                       color: isPositiveGrowth
//                                           ? Colors.green
//                                           : Colors.red,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             );
//                           }),
//                         ],
//                       );
//                     },
//                   ),
                ],
              ),
            ),
          ),
        ],
    );
  }

  // Hilfsmethoden für Statistik-Karten
  Widget _buildInventoryStatCard(
      String title,
      String value,
      IconData icon,
      Color color,
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerStatCard(
      String title,
      String value,
      IconData icon,
      Color color,
      {String? iconName} // Neuer Parameter für adaptiveIcon
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                iconName != null
                    ? getAdaptiveIcon(
                  iconName: iconName,
                  defaultIcon: icon,
                  color: color,
                  size: 24,
                )
                    : Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }




// Für alle drei KPI-Cards einen eigenen Stream-Builder mit Zeitfilter
  Widget _buildKpiSection() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        // Gesamtumsatz
        SizedBox(
          width: 320,
          child: _buildStatCard(
            'Gesamtumsatz',
            StreamBuilder<QuerySnapshot>(
              stream: _getSalesStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }

                double total = 0;
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final calculations = data['calculations'] as Map<String, dynamic>;
                  total += calculations['total'] as double;
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      NumberFormat.currency(
                        locale: 'de_CH',
                        symbol: 'CHF',
                      ).format(total),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Optional: Zeige Vergleich zum vorherigen Zeitraum
                    FutureBuilder<double>(
                        future: _getPreviousPeriodTotal(),
                        builder: (context, prevSnapshot) {
                          if (!prevSnapshot.hasData) return const SizedBox();

                          final prevTotal = prevSnapshot.data!;
                          final percentChange = prevTotal > 0
                              ? ((total - prevTotal) / prevTotal * 100)
                              : 0.0;

                          return Text(
                            '${percentChange >= 0 ? '+' : ''}${percentChange.toStringAsFixed(1)}% zum Vorzeitraum',
                            style: TextStyle(
                              fontSize: 12,
                              color: percentChange >= 0 ? Colors.green : Colors.red,
                            ),
                          );
                        }
                    ),
                  ],
                );
              },
            ),
            Icons.attach_money,
            Theme.of(context).colorScheme.primary,
            subtitle: _getTimeRangeText(),
          ),
        ),

        // Weitere KPI-Cards analog...
      ],
    );
  }

// Hilfsmethode für den Vergleichszeitraum
  Future<double> _getPreviousPeriodTotal() async {
    final DateTime startDate;
    final DateTime endDate = DateTime.now().subtract(
        Duration(
            days: selectedTimeRange == 'week' ? 7 :
            selectedTimeRange == 'month' ? 30 :
            selectedTimeRange == 'quarter' ? 90 : 365
        )
    );

    // Berechne Start des vorherigen Zeitraums
    switch (selectedTimeRange) {
      case 'week':
        startDate = endDate.subtract(const Duration(days: 7));
        break;
      case 'month':
        startDate = endDate.subtract(const Duration(days: 30));
        break;
      case 'quarter':
        startDate = endDate.subtract(const Duration(days: 90));
        break;
      case 'year':
        startDate = endDate.subtract(const Duration(days: 365));
        break;
      default:
        startDate = endDate.subtract(const Duration(days: 30));
    }

    final querySnapshot = await FirebaseFirestore.instance
        .collection('sales_receipts')
        .where('metadata.timestamp', isGreaterThan: startDate)
        .where('metadata.timestamp', isLessThan: endDate)
        .get();

    double total = 0;
    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final calculations = data['calculations'] as Map<String, dynamic>;
      total += calculations['total'] as double;
    }

    return total;
  }

// Hilfsmethode für den Zeitraum-Text
  String _getTimeRangeText() {
    switch (selectedTimeRange) {
      case 'week':
        return 'Letzte 7 Tage';
      case 'month':
        return 'Letzten 30 Tage';
      case 'quarter':
        return 'Letzten 90 Tage';
      case 'year':
        return 'Letztes Jahr';
      default:
        return 'Letzten 30 Tage';
    }
  }
// Hilfsmethode für den Zeitraum-Text
  String _getTimeRangeText2(String range) {
    switch (range) {
      case 'week':
        return 'Letzte Woche';
      case 'month':
        return 'Letzter Monat';
      case 'quarter':
        return 'Letztes Quartal';
      case 'year':
        return 'Letztes Jahr';
      default:
        return range;
    }
  }


  Widget _buildKpiCard(String title, Widget value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            value,
          ],
        ),
      ),
    );
  }

  Widget _buildSalesSection() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
    // Top-Produkte nach Umsatz
    Card(
    child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    const Text(
    'Top-Produkte nach Umsatz',
    style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    ),
    ),
    const SizedBox(height: 16),
    StreamBuilder<QuerySnapshot>(
    stream: _getSalesStream(),
    builder: (context, snapshot) {
    if (!snapshot.hasData) {
    return const Center(child: CircularProgressIndicator());
    }

    // Aggregiere Verkäufe nach Produkt
    final productSales = <String, Map<String, dynamic>>{};

    for (var doc in snapshot.data!.docs) {
    final data = doc.data() as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>;

    for (var item in items) {
    final productId = item['product_id'] as String;
    final quantity = item['quantity'] as int;
    final total = item['total'] as double;

    if (!productSales.containsKey(productId)) {
    productSales[productId] = {
    'product_name': item['product_name'],
    'quantity': 0,
    'total': 0.0,
    };
    }

    productSales[productId]!['quantity'] += quantity;
    productSales[productId]!['total'] += total;
    }
    }

    // Sortiere nach Umsatz
    final sortedProducts = productSales.entries.toList()
      ..sort((a, b) => (b.value['total'] as double)
          .compareTo(a.value['total'] as double));

    return Column(
      children: [
        // Tortendiagramm
        SizedBox(
          height: 300,
          child: PieChart(
            PieChartData(
              sections: sortedProducts.take(5).map((entry) {
                final total = entry.value['total'] as double;
                final percentage = total / sortedProducts
                    .fold(0.0, (sum, e) => sum + (e.value['total'] as double)) * 100;

                return PieChartSectionData(
                  value: total,
                  title: '${percentage.toStringAsFixed(1)}%',
                  radius: 100,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Detaillierte Liste
        ...sortedProducts.take(10).map((entry) {
          return ListTile(
            title: Text(entry.value['product_name'] as String),
            subtitle: Text('${entry.value['quantity']} Stück'),
            trailing: Text(
              NumberFormat.currency(
                locale: 'de_CH',
                symbol: 'CHF',
              ).format(entry.value['total']),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        }),
      ],
    );
    },
    ),
    ],
    ),
    ),
    ),
          const SizedBox(height: 24),

          // Lagerbestandsanalyse
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lagerbestandsbewegungen',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('stock_entries')
                          .orderBy('timestamp', descending: true)
                          .limit(100)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        // Gruppiere nach Datum und Art (Eingang/Ausgang)
                        final movements = <DateTime, Map<String, int>>{};

                        for (var doc in snapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final timestamp = data['timestamp'] as Timestamp;
                          final date = DateTime(
                            timestamp.toDate().year,
                            timestamp.toDate().month,
                            timestamp.toDate().day,
                          );
                          final quantity = data['quantity_change'] as int;

                          if (!movements.containsKey(date)) {
                            movements[date] = {
                              'inbound': 0,
                              'outbound': 0,
                            };
                          }

                          if (quantity > 0) {
                            movements[date]!['inbound'] =
                                (movements[date]!['inbound'] ?? 0) + quantity;
                          } else {
                            movements[date]!['outbound'] =
                                (movements[date]!['outbound'] ?? 0) + quantity.abs();
                          }
                        }

                        final sortedDates = movements.keys.toList()..sort();

                        return LineChart(
                          LineChartData(
                            gridData: FlGridData(show: true),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      value.toInt().toString(),
                                      style: const TextStyle(fontSize: 10),
                                    );
                                  },
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  getTitlesWidget: (value, meta) {
                                    if (value < 0 || value >= sortedDates.length) {
                                      return const SizedBox();
                                    }
                                    final date = sortedDates[value.toInt()];
                                    return Text(
                                      DateFormat('dd.MM').format(date),
                                      style: const TextStyle(fontSize: 10),
                                    );
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: true),
                            lineBarsData: [
                              // Eingänge
                              LineChartBarData(
                                spots: List.generate(sortedDates.length, (index) {
                                  final date = sortedDates[index];
                                  return FlSpot(
                                    index.toDouble(),
                                    movements[date]!['inbound']!.toDouble(),
                                  );
                                }),
                                isCurved: true,
                                color: Colors.green,
                                barWidth: 2,
                                dotData: FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.green.withOpacity(0.1),
                                ),
                              ),
                              // Ausgänge
                              LineChartBarData(
                                spots: List.generate(sortedDates.length, (index) {
                                  final date = sortedDates[index];
                                  return FlSpot(
                                    index.toDouble(),
                                    movements[date]!['outbound']!.toDouble(),
                                  );
                                }),
                                isCurved: true,
                                color: Colors.red,
                                barWidth: 2,
                                dotData: FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.red.withOpacity(0.1),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Legende
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem('Eingänge', Colors.green),
                      const SizedBox(width: 24),
                      _buildLegendItem('Ausgänge', Colors.red),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Kundenanalyse
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Top Kunden',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot>(
                    stream: _getSalesStream(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      // Aggregiere Verkäufe nach Kunde
                      final customerSales = <String, Map<String, dynamic>>{};

                      for (var doc in snapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final customer = data['customer'] as Map<String, dynamic>;
                        final customerId = customer['id'] as String;
                        final calculations = data['calculations'] as Map<String, dynamic>;
                        final total = calculations['total'] as double;

                        if (!customerSales.containsKey(customerId)) {
                          customerSales[customerId] = {
                            'customer': customer,
                            'orders': 0,
                            'total': 0.0,
                          };
                        }

                        customerSales[customerId]!['orders'] += 1;
                        customerSales[customerId]!['total'] += total;
                      }

                      // Sortiere nach Umsatz
                      final sortedCustomers = customerSales.entries.toList()
                        ..sort((a, b) => (b.value['total'] as double)
                            .compareTo(a.value['total'] as double));

                      return Column(
                        children: sortedCustomers.take(10).map((entry) {
                          final customer = entry.value['customer'] as Map<String, dynamic>;
                          return ListTile(
                            title: Text(customer['company'] as String),
                            subtitle: Text('${entry.value['orders']} Bestellungen'),
                            trailing: Text(
                              NumberFormat.currency(
                                locale: 'de_CH',
                                symbol: 'CHF',
                              ).format(entry.value['total']),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }

  static const chartLegendStyle = TextStyle(
    fontSize: 12,
    color: Color(0xFF424242),  // Dunkelgrau für bessere Lesbarkeit
  );

  static const chartTitleStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );


// Gemeinsame Widget-Komponente für die Legende
  Widget buildLegendItem(String label, Color color, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 1,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: $value',
              style: chartLegendStyle,
            ),
          ),
        ],
      ),
    );
  }
  Stream<QuerySnapshot> _getSalesStream() {
    DateTime startDate;

    switch (selectedTimeRange) {
      case 'week':
        startDate = DateTime.now().subtract(const Duration(days: 7));
        break;
      case 'month':
        startDate = DateTime.now().subtract(const Duration(days: 30));
        break;
      case 'quarter':
        startDate = DateTime.now().subtract(const Duration(days: 90));
        break;
      case 'year':
        startDate = DateTime.now().subtract(const Duration(days: 365));
        break;
      default:
        startDate = DateTime.now().subtract(const Duration(days: 30));
    }

    return FirebaseFirestore.instance
        .collection('sales_receipts')
        .where('metadata.timestamp', isGreaterThan: startDate)
        .orderBy('metadata.timestamp', descending: true)
        .snapshots();
  }
}

// Oben in der Klasse: Ein durchdachtes Farbschema
// Oben in der Klasse: Ein durchdachtes Farbschema
class ChartColors {
  // Hauptfarben für die wichtigsten Qualitäten
  static const Map<String, Color> qualityGrades = {
    'A': Color(0xFF1E88E5),   // Hauptblau
    'AB': Color(0xFF42A5F5),  // Helleres Blau
    'B': Color(0xFF90CAF9),   // Noch helleres Blau
    'BC': Color(0xFF64B5F6),  // Mittleres Blau
    'C': Color(0xFFBBDEFB),   // Sehr helles Blau
  };

  // Natürliche Holzfarben
  static const Map<String, Color> woodTypes = {
    'Fichte': Color(0xFF8D6E63),  // Warmes Braun
    'Tanne': Color(0xFF6D4C41),   // Dunkles Braun
    'Ahorn': Color(0xFFBCAAA4),   // Helles Braun
    'Buche': Color(0xFF795548),   // Mittleres Braun
    'Eiche': Color(0xFF4E342E),   // Sehr dunkles Braun
  };

  // Fallback-Farben für nicht definierte Werte
  static final List<Color> fallbackColors = [
    const Color(0xFF90A4AE),  // Blaugrau
    const Color(0xFF78909C),  // Dunkleres Blaugrau
    const Color(0xFFB0BEC5),  // Helleres Blaugrau
    const Color(0xFF607D8B),  // Mittleres Blaugrau
  ];

  static Color getQualityColor(String quality, int index) {
    return qualityGrades[quality] ?? fallbackColors[index % fallbackColors.length];
  }

  static Color getWoodColor(String woodType, int index) {
    return woodTypes[woodType] ?? fallbackColors[index % fallbackColors.length];
  }
}
class PieChartConfig {
  static const double radius = 110;
  static const double centerSpaceRadius = 40;
  static const double sectionSpace = 2;
  static const double minPercentageForLabel = 5;
}