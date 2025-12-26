import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tonewood/production/stamm_buchung_sheet.dart';

import '../analytics/roundwood/models/roundwood_models.dart';
import '../analytics/roundwood/roundwood_list.dart';
import '../analytics/roundwood/services/roundwood_service.dart';
import '../analytics/roundwood/widgets/roundwood_filter_dialog.dart';
import '../services/icon_helper.dart';

class StammAuswahlSheet extends StatefulWidget {
  final Function(String id, Map<String, dynamic> data) onStammSelected;

  const StammAuswahlSheet({required this.onStammSelected});

  @override
  State<StammAuswahlSheet> createState() => _StammAuswahlSheetState();
}

class _StammAuswahlSheetState extends State<StammAuswahlSheet> {
  final RoundwoodService _service = RoundwoodService();
  RoundwoodFilter _activeFilter = RoundwoodFilter(showClosed: false);
  List<Map<String, dynamic>> _recentStaemme = [];
  bool _isLoadingRecent = true;
  bool _hideClosedStaemme = true;

  @override
  void initState() {
    super.initState();
    debugPrint('🟢 initState - Filter bei Start: ${_activeFilter.showClosed}');

    _loadRecentStaemme();
    _loadHideClosedSetting();
  }
// ═══════════════════════════════════════════════════════════════════════════
// _loadHideClosedSetting() komplett ersetzen
// ═══════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════
// _loadHideClosedSetting() mit Debug
// ═══════════════════════════════════════════════════════════════════════════
  Future<void> _loadHideClosedSetting() async {
    debugPrint('🔵 _loadHideClosedSetting START - aktueller Filter: ${_activeFilter.showClosed}');

    try {
      final doc = await FirebaseFirestore.instance
          .collection('user_settings')
          .doc('stamm_auswahl')
          .get();

      debugPrint('🔵 Dokument existiert: ${doc.exists}');
      debugPrint('🔵 Dokument data: ${doc.data()}');

      if (doc.exists && doc.data()?['hide_closed'] != null && mounted) {
        final hideValue = doc.data()!['hide_closed'] as bool;
        debugPrint('🔵 hideValue aus DB: $hideValue');

        if (hideValue != _hideClosedStaemme) {
          debugPrint('🔵 Wert unterscheidet sich, update...');
          setState(() {
            _hideClosedStaemme = hideValue;
            _activeFilter = _activeFilter.copyWith(
              showClosed: hideValue ? false : null,
              clearShowClosed: !hideValue,
            );
          });
          debugPrint('🔵 Nach Update - Filter: ${_activeFilter.showClosed}');
        } else {
          debugPrint('🔵 Wert gleich, kein Update nötig');
        }
      } else {
        debugPrint('🔵 Kein Dokument/Wert - behalte Default');
      }
    } catch (e) {
      debugPrint('🔴 Fehler: $e');
    }

    debugPrint('🔵 _loadHideClosedSetting ENDE - Filter: ${_activeFilter.showClosed}');
  }


  Future<void> _toggleHideClosed() async {
    final newValue = !_hideClosedStaemme;

    setState(() {
      _hideClosedStaemme = newValue;
      // WICHTIG: Filter direkt neu setzen mit copyWith
      _activeFilter = _activeFilter.copyWith(
        showClosed: newValue ? false : null,
        clearShowClosed: !newValue,
      );
    });

    try {
      await FirebaseFirestore.instance
          .collection('user_settings')
          .doc('stamm_auswahl')
          .set({
        'hide_closed': newValue,
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Fehler beim Speichern der Hide-Closed-Setting: $e');
    }
  }

  Future<void> _loadRecentStaemme() async {
    try {
      // Hole die letzten 3 eindeutigen Stämme aus production_batches
      final snapshot = await FirebaseFirestore.instance
          .collection('production_batches')
          .orderBy('stock_entry_date', descending: true)
          .limit(50) // Mehr holen um 3 eindeutige zu finden
          .get();

      final seenIds = <String>{};
      final recent = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final roundwoodId = data['roundwood_id'] as String?;

        if (roundwoodId != null && !seenIds.contains(roundwoodId)) {
          seenIds.add(roundwoodId);

          // Hole Stamm-Details
          final stammDoc = await FirebaseFirestore.instance
              .collection('roundwood')
              .doc(roundwoodId)
              .get();

          if (stammDoc.exists) {
            recent.add({
              'id': roundwoodId,
              ...stammDoc.data()!,
            });
          }

          if (recent.length >= 3) break;
        }
      }

      if (mounted) {
        setState(() {
          _recentStaemme = recent;
          _isLoadingRecent = false;
        });
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der letzten Stämme: $e');
      if (mounted) setState(() => _isLoadingRecent = false);
    }
  }
  void _showFilterDialog() async {
    final result = await showDialog<RoundwoodFilter>(
      context: context,
      builder: (context) => RoundwoodFilterDialog(
        initialFilter: _activeFilter,
      ),
    );

    if (result != null) {
      setState(() => _activeFilter = result);
    }
  }
  Widget _buildRecentStaemme() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              getAdaptiveIcon(
                iconName: 'history',
                defaultIcon: Icons.history,
                color: Colors.grey[600],
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Zuletzt verwendet',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: _recentStaemme.map((stamm) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: stamm != _recentStaemme.last ? 8 : 0,
                  ),
                  child: _buildRecentStammChip(stamm),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentStammChip(Map<String, dynamic> stamm) {
    final nr = stamm['internal_number'] ?? '?';
    final jahr = stamm['year'] ?? '?';
    final holz = stamm['wood_name'] ?? stamm['wood_type'] ?? '';
    final isMondholz = stamm['is_moonwood'] ?? false;

    return InkWell(
      onTap: () => widget.onStammSelected(stamm['id'], stamm),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF0F4A29).withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$nr/$jahr',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF0F4A29),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isMondholz)
                  getAdaptiveIcon(
                    iconName: 'nightlight',
                    defaultIcon: Icons.nightlight,
                    color: const Color(0xFF0F4A29),
                    size: 14,
                  ),
              ],
            ),
            Text(
              holz,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header mit Filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
            ),
            child: Row(
              children: [
                getAdaptiveIcon(
                  iconName: 'forest',
                  defaultIcon: Icons.forest,
                  color: const Color(0xFF0F4A29),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Stamm auswählen',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F4A29),
                    ),
                  ),
                ),

                Tooltip(
                  message: _hideClosedStaemme
                      ? 'Abgeschlossene Stämme ausgeblendet'
                      : 'Alle Stämme anzeigen',
                  child: InkWell(
                    onTap: _toggleHideClosed,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _hideClosedStaemme
                            ? const Color(0xFF0F4A29).withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: getAdaptiveIcon(
                        iconName: _hideClosedStaemme ? 'visibility_off' : 'visibility',
                        defaultIcon: _hideClosedStaemme ? Icons.visibility_off : Icons.visibility,
                        color: _hideClosedStaemme
                            ? const Color(0xFF0F4A29)
                            : Colors.grey[600],
                        size: 20,
                      ),
                    ),
                  ),
                ),
                // Filter Button mit Badge
                Badge(
                  isLabelVisible: _activeFilter.toMap().isNotEmpty,
                  label: Text(_activeFilter.toMap().length.toString()),
                  child: IconButton(
                    onPressed: _showFilterDialog,
                    icon: getAdaptiveIcon(
                      iconName: 'filter_list',
                      defaultIcon: Icons.filter_list,
                    ),
                    tooltip: 'Filter',
                  ),
                ),
                IconButton(
                  icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                  onPressed: () => Navigator.pop(context),
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
// NEU: Letzte Stämme
          if (!_isLoadingRecent && _recentStaemme.isNotEmpty)
            _buildRecentStaemme(),

          // Aktive Filter anzeigen (wenn vorhanden)
          if (_activeFilter.toMap().isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF0F4A29).withOpacity(0.05),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_activeFilter.toMap().length} Filter aktiv',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF0F4A29),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _activeFilter = RoundwoodFilter()),
                    child: const Text(
                      'Zurücksetzen',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          // RoundwoodList
          Expanded(
            child: RoundwoodList(
              showHeaderActions: false,
              filter: _activeFilter,
              onFilterChanged: (filter) {
                debugPrint('⚠️ Filter geändert von: ${_activeFilter.showClosed} zu: ${filter.showClosed}');
                debugPrint('⚠️ Stack: ${StackTrace.current}');
                setState(() => _activeFilter = filter);
              }, service: _service,
              isDesktopLayout: false,
              onItemSelected: (stammId, stammData) {
                final isClosed = stammData['is_closed'] ?? false;

                if (isClosed) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Row(
                        children: [
                          getAdaptiveIcon(
                            iconName: 'lock',
                            defaultIcon: Icons.lock,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          const Text('Stamm abgeschlossen'),
                        ],
                      ),
                      content: Text(
                        'Der Stamm ${stammData['internal_number']}/${stammData['year']} wurde bereits abgeschlossen.\n\nMöchtest du ihn trotzdem öffnen?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Abbrechen'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx); // Dialog schließen
                            Navigator.pop(context); // Auswahl-Sheet schließen
                            showStammBuchungSheet(
                              context: context,
                              stammId: stammId,
                              stammData: stammData,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F4A29),
                          ),
                          child: const Text('Trotzdem öffnen', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                } else {
                  Navigator.pop(context);
                  showStammBuchungSheet(
                    context: context,
                    stammId: stammId,
                    stammData: stammData,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}