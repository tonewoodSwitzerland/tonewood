import 'package:flutter/material.dart';

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
  RoundwoodFilter _activeFilter = RoundwoodFilter();

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
              onFilterChanged: (filter) => setState(() => _activeFilter = filter),
              service: _service,
              isDesktopLayout: false,
              onItemSelected: widget.onStammSelected,
            ),
          ),
        ],
      ),
    );
  }
}