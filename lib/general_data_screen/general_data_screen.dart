import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tonewood/constants.dart';

class GeneralDataScreen extends StatefulWidget {
  const GeneralDataScreen({Key? key}) : super(key: key);

  @override
  _GeneralDataScreenState createState() => _GeneralDataScreenState();
}

class _GeneralDataScreenState extends State<GeneralDataScreen> {
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
                                'Fs',
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

  void _showAddDialog() async {
    _newItemController.clear();
    _newShortController.clear();  // Add this line
    final collection = _collections[_currentTabIndex]!;
    final nextCode = await _getNextCode(collection);

    showDialog(
      context: context,
      builder: (BuildContext context) {
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
                  'Code: $nextCode',
                  style: TextStyle(
                    fontSize: 14,
                    color: primaryAppColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${_titles[_currentTabIndex]}'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _newItemController,
                decoration: const InputDecoration(
                  labelText: 'Bezeichnung',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newShortController,
                decoration: const InputDecoration(
                  labelText: 'Abkürzung',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_newItemController.text.isNotEmpty &&
                    _newShortController.text.isNotEmpty) {  // Modified condition
                  await FirebaseFirestore.instance
                      .collection(collection)
                      .doc(nextCode)
                      .set({
                    'code': nextCode,
                    'name': _newItemController.text.trim(),
                    'short': _newShortController.text.trim(),  // Add this line
                    'created_at': FieldValue.serverTimestamp(),
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${_titles[_currentTabIndex]} wurde hinzugefügt'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Speichern'),
            ),
          ],
        );
      },
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
                        _buildNavItem('Beispiele', 0, Icons.info_outline),
                        _buildNavItem('Instrumente', 1, Icons.music_note),
                        _buildNavItem('Holzarten', 2, Icons.forest),
                        _buildNavItem('Teile', 3, Icons.category),
                        _buildNavItem('Qualitäten', 4, Icons.star),
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
                          icon: const Icon(Icons.add),
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
                    child: _buildCollectionView(_collections[_currentTabIndex]!),
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
          floatingActionButton: _currentTabIndex != 0 ? FloatingActionButton(  // Kein FAB im Beispiel-Tab
            onPressed: _showAddDialog,
            backgroundColor: Colors.white,
            child: const Icon(Icons.add, color: secondaryAppColor),
          ) : null,
        ),
      );
    }
  }

  Widget _buildNavItem(String title, int index, IconData icon) {
    final isSelected = _currentTabIndex == index;

    return Material(
      color: isSelected ? Colors.grey.shade100 : Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _currentTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? primaryAppColor : Colors.grey.shade600,
                size: 24,
              ),
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
                    color: primaryAppColor.withOpacity(0.1),
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
                subtitle:  Text(data['short']),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
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

void _showEditDialog(BuildContext context, String collection, String docId, Map<String, dynamic> data) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => EditNameDialog(
      code: data['code'],
      initialName: data['name'],
      initialShort:data['short'],
      collection: collection,
      docId: docId,
    ),
  );

  if (result == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bezeichnung wurde aktualisiert'),
        backgroundColor: Colors.green,
      ),
    );
  } else if (result == false && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fehler beim Aktualisieren'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
