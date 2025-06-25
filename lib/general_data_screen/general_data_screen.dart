import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tonewood/constants.dart';

import '../services/icon_helper.dart';

class GeneralDataScreen extends StatefulWidget {
  const GeneralDataScreen({Key? key}) : super(key: key);

  @override
  GeneralDataScreenState createState() => GeneralDataScreenState();
}

class GeneralDataScreenState extends State<GeneralDataScreen> {
  final TextEditingController _newShortController = TextEditingController();
  final TextEditingController _newItemController = TextEditingController();
  int _currentTabIndex = 0;

  final Map<int, String> _collections = {
    0: 'examples',
    1: 'instruments',
    2: 'wood_types',
    3: 'parts',
    4: 'qualities'
  };

  final Map<int, String> _titles = {
    0: 'Barcode-Beispiele',
    1: 'Instrument',
    2: 'Holzart',
    3: 'Teil',
    4: 'Qualität'
  };
  Widget _buildBarcodeExample(String data, String title) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text(
            //   title,
            //   style: TextStyle(
            //     fontSize: 14,
            //     color: Colors.grey[600],
            //   ),
            // ),
            SizedBox(height: 8),
            BarcodeWidget(
              data: data,
              barcode: Barcode.code128(),
              width: 200,
              height: 60,
            ),

          ],
        ),
      ),
    );
  }

// Neue Widget-Methode für die Beispiel-Ansicht
  Widget _buildExamplesView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Verkaufs-Barcode Beispiel
          Card(
            margin: EdgeInsets.only(bottom: 24),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verkaufs-Barcode',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryAppColor,
                    ),
                  ),
                  Divider(height: 32),
                  Text(
                    'Format: IIPP.HHQQ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1),
                      1: FlexColumnWidth(3),
                    },
                    children: [
                      TableRow(
                        children: [
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'II',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('Instrument - 18 (Ukulele)'),
                            ),
                          ),
                        ],
                      ),
                      TableRow(
                        children: [
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'PP',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('Bauteil - 13 (Hals)'),
                            ),
                          ),
                        ],
                      ),
                      TableRow(
                        children: [
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'HH',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('Holzart - 10 (Fichte)'),
                            ),
                          ),
                        ],
                      ),
                      TableRow(
                        children: [
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'QQ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('Qualität - 10 (Master)'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  _buildBarcodeExample('1813.1022', 'Beispiel eines Verkaufs-Barcodes'),

                ],
              ),
            ),
          ),

          // Produktions-Barcode Beispiel
          Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Produktions-Barcode',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryAppColor,
                    ),
                  ),
                  Divider(height: 32),
                  Text(
                    'Format: IIPP.HHQQ.ThHaMoFs.JJ.0000',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1),
                      1: FlexColumnWidth(3),
                    },
                    children: [
                      TableRow(
                        children: [
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'II',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('Instrument - 18 (Ukulele)'),
                            ),
                          ),
                        ],
                      ),
                      TableRow(
                        children: [
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'PP',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('Bauteil - 13 (Hals)'),
                            ),
                          ),
                        ],
                      ),
                      TableRow(
                        children: [
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Th',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('Thermo - 1 (Ja)'),
                            ),
                          ),
                        ],
                      ),
                      TableRow(
                        children: [
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Ha',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('Hasel - 1 (Ja)'),
                            ),
                          ),
                        ],
                      ),
                      TableRow(
                        children: [
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Mo',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('Mondholz - 0 (Nein)'),
                            ),
                          ),
                        ],
                      ),
                      TableRow(
                        children: [
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'FSC',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('FSC - 0 (Nein)'),
                            ),
                          ),
                        ],
                      ),
                      TableRow(
                        children: [
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'JJ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('Jahrgang - 24 (2024)'),
                            ),
                          ),
                        ],
                      ),
                      TableRow(
                        children: [
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                '0000',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('Produktionsnummer 1- xxxx'),
                            ),
                          ),
                        ],
                      ),

                    ],
                  ),
                  SizedBox(height: 24),
                  _buildBarcodeExample('1813.1022.1100.24.0001', 'Beispiel eines Produktions-Barcodes'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  Future<String> _getNextCode(String collection) async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection(collection)
          .where('code', isLessThan: '99')
          .orderBy('code', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return '10';
      }

      String lastCode = (snapshot.docs.first.data() as Map<String, dynamic>)['code'];
      int nextCode = int.parse(lastCode) + 1;

      print('Letzter Code: $lastCode, Nächster Code: $nextCode');

      return nextCode.toString();
    } catch (e) {
      print('Fehler bei _getNextCode: $e');
      return '10';
    }
  }

  Future<void> updateWoodTypesDatabase() async {
    final firestore = FirebaseFirestore.instance;

    // Daten aus dem Excel-Screenshot mit korrekten Feldnamen
    final woodTypesData = [
      {
        'code': '10',
        'name': 'Gemeine Fichte',
        'short': 'Fi',
        'name_latin': 'Picea abies',
        'name_english': 'Swiss alpine spruce',
        'density': 450,
        'ha_grp_1': 'NH',
        'ha_grp_2': 'Fi',
        'z_tares_1': '4408.1000',
        'z_tares_2': '4407.1200',
      },
      {
        'code': '11',
        'name': 'Weisstanne',
        'short': 'Ta',
        'name_latin': 'Abies alba',
        'name_english': 'silver fir',
        'density': 450,
        'ha_grp_1': 'NH',
        'ha_grp_2': 'Ta',
        'z_tares_1': '4408.1000',
        'z_tares_2': '4407.1200',
      },
      {
        'code': '12',
        'name': 'Bergahorn',
        'short': 'Ah',
        'name_latin': 'Acer pseudoplatanus',
        'name_english': 'sycamore maple',
        'density': 630,
        'ha_grp_1': 'a',
        'ha_grp_2': 'Ah',
        'z_tares_1': '4408.9000',
        'z_tares_2': '4407.9300',
      },
      {
        'code': '13',
        'name': 'Kirsche',
        'short': 'Ki',
        'name_latin': 'Prunus avium',
        'name_english': 'cherry',
        'density': 630,
        'ha_grp_1': 'a',
        'ha_grp_2': 'Ki',
        'z_tares_1': '4408.9000',
        'z_tares_2': '4407.9400',
      },
      {
        'code': '14',
        'name': 'Zwetschge',
        'short': 'Zw',
        'name_latin': 'Prunus domestica',
        'name_english': 'plum',
        'density': 630,
        'ha_grp_1': 'a',
        'ha_grp_2': 'a',
        'z_tares_1': '4408.9000',
        'z_tares_2': '4407.9900',
      },
      {
        'code': '15',
        'name': 'Birnbaum',
        'short': 'Bb',
        'name_latin': 'Pyrus communis',
        'name_english': 'pear',
        'density': 740,
        'ha_grp_1': 'a',
        'ha_grp_2': 'a',
        'z_tares_1': '4408.9000',
        'z_tares_2': '4407.9900',
      },
      {
        'code': '16',
        'name': 'Apfelbaum',
        'short': 'Ap',
        'name_latin': 'Malus domestica',
        'name_english': 'apple tree',
        'density': 740,
        'ha_grp_1': 'a',
        'ha_grp_2': 'a',
        'z_tares_1': '4408.9000',
        'z_tares_2': '4407.9900',
      },
      {
        'code': '17',
        'name': 'Elsbeere',
        'short': 'Eb',
        'name_latin': 'Sorbus torminalis',
        'name_english': 'Wild service tree',
        'density': 630,
        'ha_grp_1': 'a',
        'ha_grp_2': 'a',
        'z_tares_1': '4408.9000',
        'z_tares_2': '4407.9900',
      },
      {
        'code': '18',
        'name': 'Nussbaum',
        'short': 'Nb',
        'name_latin': 'Juglans regia',
        'name_english': 'walnut',
        'density': 630,
        'ha_grp_1': 'a',
        'ha_grp_2': 'a',
        'z_tares_1': '4408.9000',
        'z_tares_2': '4407.9900',
      },
      {
        'code': '19',
        'name': 'Schwarznuss',
        'short': 'Sn',
        'name_latin': 'Juglans nigra',
        'name_english': 'black walnut',
        'density': 630,
        'ha_grp_1': 'a',
        'ha_grp_2': 'a',
        'z_tares_1': '4408.9000',
        'z_tares_2': '4407.9900',
      },
      {
        'code': '20',
        'name': 'Lärche',
        'short': 'Lä',
        'name_latin': 'Larix decidua',
        'name_english': 'European larch',
        'density': 540,
        'ha_grp_1': 'NH',
        'ha_grp_2': 'FöH',
        'z_tares_1': '4408.1000',
        'z_tares_2': '4407.1100',
      },
      {
        'code': '21',
        'name': 'Föhre',
        'short': 'Fö',
        'name_latin': 'Pinus sylvestris',
        'name_english': 'pine',
        'density': 450,
        'ha_grp_1': 'NH',
        'ha_grp_2': 'FöH',
        'z_tares_1': '4408.1000',
        'z_tares_2': '4407.1100',
      },
      {
        'code': '22',
        'name': 'Arve',
        'short': 'Av',
        'name_latin': 'Pinus cembra',
        'name_english': 'Swiss pine',
        'density': 450,
        'ha_grp_1': 'NH',
        'ha_grp_2': 'FöH',
        'z_tares_1': '4408.1000',
        'z_tares_2': '4407.1100',
      },
      {
        'code': '23',
        'name': 'Eibe',
        'short': 'Eib',
        'name_latin': 'Taxus baccata',
        'name_english': 'European yew',
        'density': 600,
        'ha_grp_1': 'NH',
        'ha_grp_2': 'NH a',
        'z_tares_1': '4408.1000',
        'z_tares_2': '4407.1900',
      },
      {
        'code': '24',
        'name': 'Scheinzypresse',
        'short': 'Szy',
        'name_latin': 'Chamaecyparis',
        'name_english': 'false cypress',
        'density': 600,
        'ha_grp_1': 'NH',
        'ha_grp_2': 'NH a',
        'z_tares_1': '4408.1000',
        'z_tares_2': '4407.1900',
      },
      {
        'code': '25',
        'name': 'Buche',
        'short': 'Bu',
        'name_latin': 'Fagus sylvatica',
        'name_english': 'European beech',
        'density': 690,
        'ha_grp_1': 'a',
        'ha_grp_2': 'Bu',
        'z_tares_1': '4408.9000',
        'z_tares_2': '4407.9200',
      },
      {
        'code': '26',
        'name': 'Esche',
        'short': 'Es',
        'name_latin': 'Fraxinus excelsior',
        'name_english': 'ash',
        'density': 690,
        'ha_grp_1': 'a',
        'ha_grp_2': 'Es',
        'z_tares_1': '4408.9000',
        'z_tares_2': '4407.9500',
      },
      {
        'code': '27',
        'name': 'Erle',
        'short': 'Er',
        'name_latin': 'Alnus glutinosa',
        'name_english': 'black alder',
        'density': 690,
        'ha_grp_1': 'a',
        'ha_grp_2': 'a',
        'z_tares_1': '4408.9000',
        'z_tares_2': '4407.9900',
      },
      {
        'code': '28',
        'name': 'Hagebuche',
        'short': 'Hbu',
        'name_latin': 'Carpinus betulus',
        'name_english': 'Hornbeam',
        'density': 690,
        'ha_grp_1': 'a',
        'ha_grp_2': 'a',
        'z_tares_1': '4408.9000',
        'z_tares_2': '4407.9900',
      },
      {
        'code': '29',
        'name': 'Ulme',
        'short': 'Ul',
        'name_latin': 'Ulmus',
        'name_english': 'Elm',
        'density': 690,
        'ha_grp_1': 'a',
        'ha_grp_2': 'a',
        'z_tares_1': '4408.9000',
        'z_tares_2': '4407.9900',
      },
      {
        'code': '30',
        'name': 'Eiche',
        'short': 'Ei',
        'name_latin': 'Quercus robur',
        'name_english': 'English oak',
        'density': 690,
        'ha_grp_1': 'a',
        'ha_grp_2': 'Ei',
        'z_tares_1': '4408.9000',
        'z_tares_2': '4407.9100',
      },
      {
        'code': '31',
        'name': 'Roteiche',
        'short': 'Rei',
        'name_latin': 'Quercus rubra',
        'name_english': 'red oak',
        'density': 690,
        'ha_grp_1': 'a',
        'ha_grp_2': 'Ei',
        'z_tares_1': '4408.9000',
        'z_tares_2': '4407.9100',
      },
      {
        'code': '32',
        'name': 'Platane',
        'short': 'Pla',
        'name_latin': 'Platanus x acerifolia',
        'name_english': 'London plane tree',
        'density': 620,
        'ha_grp_1': 'a',
        'ha_grp_2': 'a',
        'z_tares_1': '4408.9000',
        'z_tares_2': '4407.9900',
      },
      {
        'code': '33',
        'name': 'Gleditschie',
        'short': 'Gled',
        'name_latin': 'Gleditsia triacanthos',
        'name_english': 'Honey locust',
        'density': 620,
        'ha_grp_1': 'a',
        'ha_grp_2': 'a',
        'z_tares_1': '4408.9000',
        'z_tares_2': '4407.9900',
      },
    ];

    // Batch-Update für bessere Performance
    WriteBatch batch = firestore.batch();

    for (var woodType in woodTypesData) {
      DocumentReference docRef = firestore.collection('wood_types').doc(woodType['code'] as String);
      batch.set(docRef, {
        ...woodType,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // Merge: true behält existierende Felder bei
    }

    try {
      await batch.commit();
      print('Erfolgreich ${woodTypesData.length} Holzarten aktualisiert!');
    } catch (e) {
      print('Fehler beim Update: $e');
    }
  }





  void _showAddDialog() async {
    _newItemController.clear();
    _newShortController.clear();
    final collection = _collections[_currentTabIndex]!;
    final nextCode = await _getNextCode(collection);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: _AddItemDialog(
          collection: collection,
          nextCode: nextCode,
          title: _titles[_currentTabIndex]!,
          isWoodTypes: _currentTabIndex == 2,
          onSave: () {
            _resetAndReload();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopLayout = screenWidth > 900;

    if (isDesktopLayout) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Stammdaten', style: headline4_0),
          centerTitle: true,
        ),
        body: Row(
          children: [
            // Linke Seite - Navigation und Eingabe
            Container(
              width: 300,
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
                  // Navigationsliste
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      children: [
                        _buildNavItem(
                            'Beispiele',
                            0,
                            getAdaptiveIcon(
                              iconName: 'barcode',
                              defaultIcon: Icons.qr_code_scanner, // Korrekte Icon-Konstante
                              color: _currentTabIndex == 0 ? primaryAppColor : Colors.grey.shade600,
                            )
                        ),
                        _buildNavItem(
                            'Instrumente',
                            1,
                            getAdaptiveIcon(
                              iconName: 'music_note',
                              defaultIcon: Icons.music_note,
                              color: _currentTabIndex == 1 ? primaryAppColor : Colors.grey.shade600,
                            )
                        ),
                        _buildNavItem(
                            'Holzarten',
                            2,
                            getAdaptiveIcon(
                              iconName: 'forest',
                              defaultIcon: Icons.forest,
                              color: _currentTabIndex == 2 ? primaryAppColor : Colors.grey.shade600,
                            )
                        ),
                        _buildNavItem(
                            'Teile',
                            3,
                            getAdaptiveIcon(
                              iconName: 'category',
                              defaultIcon: Icons.category,
                              color: _currentTabIndex == 3 ? primaryAppColor : Colors.grey.shade600,
                            )
                        ),
                        _buildNavItem(
                            'Qualitäten',
                            4,
                            getAdaptiveIcon(
                              iconName: 'star',
                              defaultIcon: Icons.star,
                              color: _currentTabIndex == 4 ? primaryAppColor : Colors.grey.shade600,
                            )
                        ),
                      ],
                    ),
                  ),
                  // Eingabebereich
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Neuer Eintrag',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryAppColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_currentTabIndex != 0)  ElevatedButton.icon(
                          onPressed: _showAddDialog,
                          icon: getAdaptiveIcon(
                            iconName: 'add',
                            defaultIcon: Icons.add,
                            color: Colors.grey.shade600, // Standardfarbe für das Icon
                          ),
                          label: Text('${_titles[_currentTabIndex]} hinzufügen'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: secondaryAppColor,
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Rechte Seite - Listenansicht
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      _titles[_currentTabIndex]!,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _currentTabIndex == 0
                        ? _buildExamplesView()
                        : _buildCollectionView(_collections[_currentTabIndex]!),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // Mobile Layout (bisheriger Code)
      return DefaultTabController(
        length: 5,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Stammdaten', style: headline4_0),
            centerTitle: true,
            bottom: TabBar(
              onTap: (index) {
                setState(() {
                  _currentTabIndex = index;
                });
              },
              tabs: const [
                Tab(text: 'Barcode'),
                Tab(text: 'Instrumente'),
                Tab(text: 'Holz'),
                Tab(text: 'Teile'),
                Tab(text: 'Qualitäten'),
              ],
            ),
          ),
          body: TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildExamplesView(),
              _buildCollectionView('instruments'),
              _buildCollectionView('wood_types'),
              _buildCollectionView('parts'),
              _buildCollectionView('qualities'),
            ],
          ),
          floatingActionButton: _currentTabIndex != 0 ? FloatingActionButton(
            onPressed: _showAddDialog,
            backgroundColor: Colors.white,
            child: getAdaptiveIcon(
              iconName: 'add',
              defaultIcon: Icons.add,
              color: Colors.grey.shade600, // Standardfarbe für das Icon
            ),
          ) : null,
        ),
      );
    }
  }

  Widget _buildNavItem(String title, int index, dynamic iconData) {
    final isSelected = _currentTabIndex == index;

    return Material(
      color: isSelected ? Colors.grey.shade100 : Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _currentTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              // Prüft, ob iconData ein IconData oder ein Widget ist
              iconData is IconData
                  ? Icon(
                iconData,
                color: isSelected ? primaryAppColor : Colors.grey.shade600,
                size: 24,
              )
                  : iconData, // Wenn es bereits ein Widget ist (z.B. von getAdaptiveIcon)
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? primaryAppColor : Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionView(String collection) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .orderBy('code')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(

                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    data['code'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryAppColor,
                    ),
                  ),
                ),
                title: Text(data['name']),
                subtitle: Text(data['short']),
                trailing: IconButton(
                  icon: getAdaptiveIcon(
                    iconName: 'edit',
                    defaultIcon: Icons.edit,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: () => _showEditDialog(context, collection, doc.id, data),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _newItemController.dispose();
    super.dispose();
  }

  void _resetAndReload() {
    setState(() {
      // Dadurch wird das StreamBuilder in _buildCollectionView neu geladen
    });
  }
}




class EditNameDialog extends StatefulWidget {
  final String code;
  final String initialName;
  final String initialShort;

  final String collection;
  final String docId;

  const EditNameDialog({
    Key? key,
    required this.code,
    required this.initialName,
    required this.initialShort,
    required this.collection,
    required this.docId,
  }) : super(key: key);

  @override
  State<EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<EditNameDialog> {
  late TextEditingController _controller;
  late TextEditingController _shortController;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _shortController = TextEditingController(text: widget.initialShort);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: primaryAppColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Code: ${widget.code}',
              style: TextStyle(
                fontSize: 14,
                color: primaryAppColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text('Bezeichnung'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _shortController,
            decoration: const InputDecoration(
              labelText: 'Abkürzung',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_controller.text.isNotEmpty &&
                _shortController.text.isNotEmpty) {
              try {
                await FirebaseFirestore.instance
                    .collection(widget.collection)
                    .doc(widget.docId)
                    .update({
                  'name': _controller.text.trim(),
                  'short': _shortController.text.trim(),
                  'updated_at': FieldValue.serverTimestamp(),
                });

                if (!mounted) return;
                Navigator.of(context).pop(true);
              } catch (e) {
                if (!mounted) return;
                Navigator.of(context).pop(false);
              }
            }
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}


// Erweiterte _showAddDialog Methode für general_data_screen.dart
// Diese ersetzt die existierende _showAddDialog Methode


// Neue Dialog-Klasse für Add Item
class _AddItemDialog extends StatefulWidget {
  final String collection;
  final String nextCode;
  final String title;
  final bool isWoodTypes;
  final VoidCallback onSave;

  const _AddItemDialog({
    Key? key,
    required this.collection,
    required this.nextCode,
    required this.title,
    required this.isWoodTypes,
    required this.onSave,
  }) : super(key: key);

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _shortController = TextEditingController();

  // Zusätzliche Controller für Holzarten
  final TextEditingController _latinController = TextEditingController();
  final TextEditingController _englishController = TextEditingController();
  final TextEditingController _densityController = TextEditingController();
  final TextEditingController _haGrp1Controller = TextEditingController();
  final TextEditingController _haGrp2Controller = TextEditingController();
  final TextEditingController _zTares1Controller = TextEditingController();
  final TextEditingController _zTares2Controller = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _shortController.dispose();
    _latinController.dispose();
    _englishController.dispose();
    _densityController.dispose();
    _haGrp1Controller.dispose();
    _haGrp2Controller.dispose();
    _zTares1Controller.dispose();
    _zTares2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Drag Handle
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryAppColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Code: ${widget.nextCode}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryAppColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Neue ${widget.title}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: getAdaptiveIcon(
                  iconName: 'close',
                  defaultIcon: Icons.close,
                ),
              ),
            ],
          ),
        ),

        Divider(height: 1, thickness: 1, color: Colors.grey.shade200),

        // Form Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Basis-Informationen
                  _buildSectionHeader(
                    context,
                    'Basis-Informationen',
                    Icons.info_outline,
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Bezeichnung (Deutsch) *',
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            prefixIcon: getAdaptiveIcon(
                              iconName: 'label',
                              defaultIcon: Icons.label,
                            ),
                          ),
                          validator: (value) => value?.isEmpty == true
                              ? 'Bitte Bezeichnung eingeben'
                              : null,
                          autofocus: true,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _shortController,
                          decoration: InputDecoration(
                            labelText: 'Abkürzung *',
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            prefixIcon: getAdaptiveIcon(
                              iconName: 'short_text',
                              defaultIcon: Icons.short_text,
                            ),
                          ),
                          validator: (value) => value?.isEmpty == true
                              ? 'Bitte Abkürzung eingeben'
                              : null,
                        ),
                      ],
                    ),
                  ),

                  // Zusätzliche Felder nur für Holzarten
                  if (widget.isWoodTypes) ...[
                    const SizedBox(height: 24),

                    // Wissenschaftliche Bezeichnungen
                    _buildSectionHeader(
                      context,
                      'Wissenschaftliche Bezeichnungen',
                      Icons.science_outlined,
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _latinController,
                            decoration: InputDecoration(
                              labelText: 'Lateinischer Name',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              prefixIcon: getAdaptiveIcon(
                                iconName: 'translate',
                                defaultIcon: Icons.translate,
                              ),
                              hintText: 'z.B. Picea abies',
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _englishController,
                            decoration: InputDecoration(
                              labelText: 'Englische Bezeichnung',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              prefixIcon: getAdaptiveIcon(
                                iconName: 'language',
                                defaultIcon: Icons.language,
                              ),
                              hintText: 'z.B. Swiss alpine spruce',
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Physikalische Eigenschaften
                    _buildSectionHeader(
                      context,
                      'Physikalische Eigenschaften',
                      Icons.straighten_outlined,
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: TextFormField(
                        controller: _densityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Dichte (kg/m³)',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          prefixIcon: getAdaptiveIcon(
                            iconName: 'grain',
                            defaultIcon: Icons.grain,
                          ),
                          suffixText: 'kg/m³',
                          hintText: 'z.B. 450',
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Klassifizierung
                    _buildSectionHeader(
                      context,
                      'Klassifizierung',
                      Icons.category_outlined,
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _haGrp1Controller,
                                  decoration: InputDecoration(
                                    labelText: 'HA-Grp 1',
                                    border: const OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surface,
                                    hintText: 'z.B. NH oder a',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _haGrp2Controller,
                                  decoration: InputDecoration(
                                    labelText: 'HA-Grp 2',
                                    border: const OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surface,
                                    hintText: 'z.B. Fi, Ta, etc.',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Zolltarife
                    _buildSectionHeader(
                      context,
                      'Zolltarife',
                      Icons.receipt_long_outlined,
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _zTares1Controller,
                                  decoration: InputDecoration(
                                    labelText: 'Zolltarif TARES 1',
                                    border: const OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surface,
                                    hintText: 'z.B. 4408.1000',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _zTares2Controller,
                                  decoration: InputDecoration(
                                    labelText: 'Zolltarif TARES 2',
                                    border: const OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surface,
                                    hintText: 'z.B. 4407.1200',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 80), // Extra space for button
                ],
              ),
            ),
          ),
        ),

        // Action Buttons - Fixed at bottom
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: getAdaptiveIcon(
                      iconName: 'cancel',
                      defaultIcon: Icons.cancel,
                    ),
                    label: const Text('Abbrechen'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: getAdaptiveIcon(
                      iconName: 'save',
                      defaultIcon: Icons.save,
                    ),
                    label: const Text('Speichern'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  void _save() async {
    if (_formKey.currentState?.validate() == true) {
      Map<String, dynamic> data = {
        'code': widget.nextCode,
        'name': _nameController.text.trim(),
        'short': _shortController.text.trim(),
        'created_at': FieldValue.serverTimestamp(),
      };

      // Zusätzliche Felder für Holzarten hinzufügen
      if (widget.isWoodTypes) {
        data.addAll({
          'name_latin': _latinController.text.trim(),
          'name_english': _englishController.text.trim(),
          'density': int.tryParse(_densityController.text) ?? 0,
          'ha_grp_1': _haGrp1Controller.text.trim(),
          'ha_grp_2': _haGrp2Controller.text.trim(),
          'z_tares_1': _zTares1Controller.text.trim(),
          'z_tares_2': _zTares2Controller.text.trim(),
        });
      }

      try {
        await FirebaseFirestore.instance
            .collection(widget.collection)
            .doc(widget.nextCode)
            .set(data);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.title} wurde hinzugefügt'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onSave();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

// Angepasste _showEditDialog Funktion
void _showEditDialog(BuildContext context, String collection, String docId, Map<String, dynamic> data) async {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ExtendedEditNameDialog(
        code: data['code'],
        initialName: data['name'],
        initialShort: data['short'],
        data: data,
        collection: collection,
        docId: docId,
      ),
    ),
  );
}

// Erweiterte Edit Dialog Klasse für Holzarten
class ExtendedEditNameDialog extends StatefulWidget {
  final String code;
  final String initialName;
  final String initialShort;
  final Map<String, dynamic> data;
  final String collection;
  final String docId;

  const ExtendedEditNameDialog({
    Key? key,
    required this.code,
    required this.initialName,
    required this.initialShort,
    required this.data,
    required this.collection,
    required this.docId,
  }) : super(key: key);

  @override
  State<ExtendedEditNameDialog> createState() => _ExtendedEditNameDialogState();
}

class _ExtendedEditNameDialogState extends State<ExtendedEditNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _controller;
  late TextEditingController _shortController;
  late TextEditingController _latinController;
  late TextEditingController _englishController;
  late TextEditingController _densityController;
  late TextEditingController _haGrp1Controller;
  late TextEditingController _haGrp2Controller;
  late TextEditingController _zTares1Controller;
  late TextEditingController _zTares2Controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _shortController = TextEditingController(text: widget.initialShort);

    // Initialisiere zusätzliche Controller für Holzarten
    _latinController = TextEditingController(text: widget.data['name_latin'] ?? '');
    _englishController = TextEditingController(text: widget.data['name_english'] ?? '');
    _densityController = TextEditingController(text: widget.data['density']?.toString() ?? '');
    _haGrp1Controller = TextEditingController(text: widget.data['ha_grp_1'] ?? '');
    _haGrp2Controller = TextEditingController(text: widget.data['ha_grp_2'] ?? '');
    _zTares1Controller = TextEditingController(text: widget.data['z_tares_1'] ?? '');
    _zTares2Controller = TextEditingController(text: widget.data['z_tares_2'] ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    _shortController.dispose();
    _latinController.dispose();
    _englishController.dispose();
    _densityController.dispose();
    _haGrp1Controller.dispose();
    _haGrp2Controller.dispose();
    _zTares1Controller.dispose();
    _zTares2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWoodTypes = widget.collection == 'wood_types';

    return Column(
      children: [
        // Drag Handle
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryAppColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Code: ${widget.code}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryAppColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Bearbeiten',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: getAdaptiveIcon(
                  iconName: 'close',
                  defaultIcon: Icons.close,
                ),
              ),
            ],
          ),
        ),

        Divider(height: 1, thickness: 1, color: Colors.grey.shade200),

        // Form Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Basis-Informationen
                  _buildSectionHeader(
                    context,
                    'Basis-Informationen',
                    Icons.info_outline,
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _controller,
                          decoration: InputDecoration(
                            labelText: 'Bezeichnung (Deutsch) *',
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            prefixIcon: getAdaptiveIcon(
                              iconName: 'label',
                              defaultIcon: Icons.label,
                            ),
                          ),
                          validator: (value) => value?.isEmpty == true
                              ? 'Bitte Bezeichnung eingeben'
                              : null,
                          autofocus: true,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _shortController,
                          decoration: InputDecoration(
                            labelText: 'Abkürzung *',
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            prefixIcon: getAdaptiveIcon(
                              iconName: 'short_text',
                              defaultIcon: Icons.short_text,
                            ),
                          ),
                          validator: (value) => value?.isEmpty == true
                              ? 'Bitte Abkürzung eingeben'
                              : null,
                        ),
                      ],
                    ),
                  ),

                  // Zusätzliche Felder nur für Holzarten
                  if (isWoodTypes) ...[
                    const SizedBox(height: 24),

                    // Wissenschaftliche Bezeichnungen
                    _buildSectionHeader(
                      context,
                      'Wissenschaftliche Bezeichnungen',
                      Icons.science_outlined,
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _latinController,
                            decoration: InputDecoration(
                              labelText: 'Lateinischer Name',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              prefixIcon: getAdaptiveIcon(
                                iconName: 'translate',
                                defaultIcon: Icons.translate,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _englishController,
                            decoration: InputDecoration(
                              labelText: 'Englische Bezeichnung',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              prefixIcon: getAdaptiveIcon(
                                iconName: 'language',
                                defaultIcon: Icons.language,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Physikalische Eigenschaften
                    _buildSectionHeader(
                      context,
                      'Physikalische Eigenschaften',
                      Icons.straighten_outlined,
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: TextFormField(
                        controller: _densityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Dichte (kg/m³)',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          prefixIcon: getAdaptiveIcon(
                            iconName: 'grain',
                            defaultIcon: Icons.grain,
                          ),
                          suffixText: 'kg/m³',
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Klassifizierung
                    _buildSectionHeader(
                      context,
                      'Klassifizierung',
                      Icons.category_outlined,
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _haGrp1Controller,
                                  decoration: InputDecoration(
                                    labelText: 'HA-Grp 1',
                                    border: const OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _haGrp2Controller,
                                  decoration: InputDecoration(
                                    labelText: 'HA-Grp 2',
                                    border: const OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Zolltarife
                    _buildSectionHeader(
                      context,
                      'Zolltarife',
                      Icons.receipt_long_outlined,
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _zTares1Controller,
                                  decoration: InputDecoration(
                                    labelText: 'Zolltarif TARES 1',
                                    border: const OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _zTares2Controller,
                                  decoration: InputDecoration(
                                    labelText: 'Zolltarif TARES 2',
                                    border: const OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 80), // Extra space for button
                ],
              ),
            ),
          ),
        ),

        // Action Buttons - Fixed at bottom
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: getAdaptiveIcon(
                      iconName: 'cancel',
                      defaultIcon: Icons.cancel,
                    ),
                    label: const Text('Abbrechen'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: getAdaptiveIcon(
                      iconName: 'save',
                      defaultIcon: Icons.save,
                    ),
                    label: const Text('Speichern'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  void _save() async {
    if (_formKey.currentState?.validate() == true) {
      try {
        Map<String, dynamic> updateData = {
          'name': _controller.text.trim(),
          'short': _shortController.text.trim(),
          'updated_at': FieldValue.serverTimestamp(),
        };

        // Zusätzliche Felder für Holzarten
        if (widget.collection == 'wood_types') {
          updateData.addAll({
            'name_latin': _latinController.text.trim(),
            'name_english': _englishController.text.trim(),
            'density': int.tryParse(_densityController.text) ?? 0,
            'ha_grp_1': _haGrp1Controller.text.trim(),
            'ha_grp_2': _haGrp2Controller.text.trim(),
            'z_tares_1': _zTares1Controller.text.trim(),
            'z_tares_2': _zTares2Controller.text.trim(),
          });
        }

        await FirebaseFirestore.instance
            .collection(widget.collection)
            .doc(widget.docId)
            .update(updateData);

        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Eintrag wurde aktualisiert'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
