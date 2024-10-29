import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tonewood/constants.dart';

class GeneralDataScreen extends StatefulWidget {
  const GeneralDataScreen({Key? key}) : super(key: key);

  @override
  _GeneralDataScreenState createState() => _GeneralDataScreenState();
}

class _GeneralDataScreenState extends State<GeneralDataScreen> {
  final TextEditingController _newItemController = TextEditingController();
  int _currentTabIndex = 0;

  final Map<int, String> _collections = {
    0: 'instruments',
    1: 'wood_types',
    2: 'parts',
    3: 'qualities'
  };

  final Map<int, String> _titles = {
    0: 'Instrument',
    1: 'Holzart',
    2: 'Teil',
    3: 'Qualität'
  };


  Future<String> _getNextCode(String collection) async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection(collection)
          .where('code', isLessThan: '99') // Nur Codes kleiner als 99
          .orderBy('code', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return '10'; // Startcode wenn keine Einträge existieren
      }

      String lastCode = (snapshot.docs.first.data() as Map<String, dynamic>)['code'];
      int nextCode = int.parse(lastCode) + 1;

      print('Letzter Code: $lastCode, Nächster Code: $nextCode'); // Debug-Ausgabe

      return nextCode.toString();
    } catch (e) {
      print('Fehler bei _getNextCode: $e');
      return '10'; // Fallback
    }
  }

  void _showAddDialog() {
    _newItemController.clear();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${_titles[_currentTabIndex]} hinzufügen'),
          content: TextField(
            controller: _newItemController,
            decoration: InputDecoration(
              labelText: 'Bezeichnung',
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_newItemController.text.isNotEmpty) {
                  final collection = _collections[_currentTabIndex]!;
                  final newCode = await _getNextCode(collection);

                  await FirebaseFirestore.instance
                      .collection(collection)
                      .doc(newCode)
                      .set({
                    'code': newCode,
                    'name': _newItemController.text.trim(),
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
    return DefaultTabController(
      length: 4,
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
              Tab(text: 'Instrumente'),
              Tab(text: 'Holzarten'),
              Tab(text: 'Teile'),
              Tab(text: 'Qualitäten'),
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildCollectionView('instruments'),
            _buildCollectionView('wood_types'),
            _buildCollectionView('parts'),
            _buildCollectionView('qualities'),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddDialog,
          backgroundColor: Colors.white,
          child: const Icon(Icons.add,color: secondaryAppColor,),
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


// Neues StatefulWidget für den Dialog
class EditNameDialog extends StatefulWidget {
  final String code;
  final String initialName;
  final String collection;
  final String docId;

  const EditNameDialog({
    Key? key,
    required this.code,
    required this.initialName,
    required this.collection,
    required this.docId,
  }) : super(key: key);

  @override
  State<EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<EditNameDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Name',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_controller.text.isNotEmpty) {
              try {
                await FirebaseFirestore.instance
                    .collection(widget.collection)
                    .doc(widget.docId)
                    .update({
                  'name': _controller.text.trim(),
                  'updated_at': FieldValue.serverTimestamp(),
                });

                if (!mounted) return;
                Navigator.of(context).pop(true); // true für erfolgreiche Aktualisierung
              } catch (e) {
                if (!mounted) return;
                Navigator.of(context).pop(false); // false für Fehler
              }
            }
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

// Angepasste showEditDialog Methode
void _showEditDialog(BuildContext context, String collection, String docId, Map<String, dynamic> data) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => EditNameDialog(
      code: data['code'],
      initialName: data['name'],
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