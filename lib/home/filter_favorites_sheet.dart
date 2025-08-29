import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/icon_helper.dart';
import '../constants.dart';

class FilterFavoritesSheet {
  static void show(BuildContext context, {
    required Function(Map<String, dynamic>) onFavoriteSelected,
    required Function() onCreateNew,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterFavoritesContent(
        onFavoriteSelected: onFavoriteSelected,
        onCreateNew: onCreateNew,
      ),
    );
  }
}

class _FilterFavoritesContent extends StatefulWidget {
  final Function(Map<String, dynamic>) onFavoriteSelected;
  final Function() onCreateNew;

  const _FilterFavoritesContent({
    required this.onFavoriteSelected,
    required this.onCreateNew,
  });

  @override
  _FilterFavoritesContentState createState() => _FilterFavoritesContentState();
}

class _FilterFavoritesContentState extends State<_FilterFavoritesContent> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            margin: EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryAppColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: getAdaptiveIcon(
                    iconName: 'favorite',
                    defaultIcon: Icons.favorite,
                    color: primaryAppColor,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Filter-Favoriten',
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

          Divider(height: 1),

          // Favoriten Liste
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('general_data')
                  .doc('filter_settings')
                  .collection('favorites')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Fehler: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final favorites = snapshot.data!.docs;

                if (favorites.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        getAdaptiveIcon(
                          iconName: 'favorite_border',
                          defaultIcon: Icons.favorite_border,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Noch keine Favoriten gespeichert',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onCreateNew();
                          },
                          child: Text('Ersten Favoriten erstellen'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: favorites.length,
                  itemBuilder: (context, index) {
                    final doc = favorites[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryAppColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: getAdaptiveIcon(
                            iconName: data['isSearch'] == true ? 'search' : 'filter_list',
                            defaultIcon: data['isSearch'] == true ? Icons.search : Icons.filter_list,
                            color: primaryAppColor,
                          ),
                        ),
                        title: Text(
                          data['name'] ?? 'Unbenannter Favorit',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: _buildFavoriteSubtitle(data),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: getAdaptiveIcon(
                                iconName: 'edit',
                                defaultIcon: Icons.edit,
                                color: Colors.grey,
                              ),
                              onPressed: () => _editFavoriteName(doc.id, data['name']),
                            ),
                            IconButton(
                              icon: getAdaptiveIcon(
                                iconName: 'delete',
                                defaultIcon: Icons.delete,
                                color: Colors.red,
                              ),
                              onPressed: () => _deleteFavorite(doc.id, data['name']),
                            ),
                          ],
                        ),
                        onTap: () {
                          widget.onFavoriteSelected(data);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(16),
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
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onCreateNew();
                  },
                  icon: getAdaptiveIcon(
                    iconName: 'add',
                    defaultIcon: Icons.add,
                    color: Colors.white,
                  ),
                  label: Text('Akt. Filter speichern',   style: TextStyle(color: Colors.white),),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryAppColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteSubtitle(Map<String, dynamic> data) {
    if (data['isSearch'] == true) {
      return Text('Suche: "${data['searchText']}"');
    }

    List<String> filterInfo = [];

    if (data['instrumentCodes']?.isNotEmpty ?? false) {
      filterInfo.add('${(data['instrumentCodes'] as List).length} Instrumente');
    }
    if (data['partCodes']?.isNotEmpty ?? false) {
      filterInfo.add('${(data['partCodes'] as List).length} Bauteile');
    }
    if (data['woodCodes']?.isNotEmpty ?? false) {
      filterInfo.add('${(data['woodCodes'] as List).length} Holzarten');
    }
    if (data['qualityCodes']?.isNotEmpty ?? false) {
      filterInfo.add('${(data['qualityCodes'] as List).length} Qualitäten');
    }

    return Text(
      filterInfo.isEmpty ? 'Keine Filter' : filterInfo.join(', '),
      style: TextStyle(fontSize: 12),
    );
  }

  void _editFavoriteName(String docId, String? currentName) {
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Favorit umbenennen'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('general_data')
                    .doc('filter_settings')
                    .collection('favorites')
                    .doc(docId)
                    .update({'name': newName});
                Navigator.pop(context);
              }
            },
            child: Text('Speichern'),
          ),
        ],
      ),
    );
  }

  void _deleteFavorite(String docId, String? name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Favorit löschen?'),
        content: Text('Möchten Sie "${name ?? 'diesen Favoriten'}" wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('general_data')
                  .doc('filter_settings')
                  .collection('favorites')
                  .doc(docId)
                  .delete();
              Navigator.pop(context);
            },
            child: Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}