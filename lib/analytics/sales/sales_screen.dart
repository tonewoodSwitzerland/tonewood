// lib/analytics/sales/screens/sales_screen.dart

import 'package:flutter/material.dart';
import 'package:tonewood/analytics/sales/screens/sales_country_view.dart';

import 'package:tonewood/analytics/sales/screens/sales_kpi_view.dart';
import 'package:tonewood/analytics/sales/screens/sales_product_view.dart';

import '../../../services/icon_helper.dart';

import 'models/sales_filter.dart';

class SalesScreenAnalytics extends StatefulWidget {
  final bool isDesktopLayout;

  const SalesScreenAnalytics({
    Key? key,
    required this.isDesktopLayout,
  }) : super(key: key);

  @override
  SalesScreenState createState() => SalesScreenState();
}

class SalesScreenState extends State<SalesScreenAnalytics> {
  String _selectedView = 'kpi'; // 'kpi', 'country', 'product'

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Navigation Bar
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.surfaceVariant,
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,  // ← hinzufügen
            children: [
              // View Navigation Buttons
              _buildNavButton(
                id: 'kpi',
                icon: Icons.dashboard,
                iconName: 'dashboard',
                label: 'Übersicht',
                tooltip: 'KPI-Übersicht',
              ),
              _buildNavButton(
                id: 'country',
                icon: Icons.public,
                iconName: 'public',
                label: 'Länder',
                tooltip: 'Länder-Analyse',
              ),
              _buildNavButton(
                id: 'product',
                icon: Icons.category,
                iconName: 'category',
                label: 'Produkte',
                tooltip: 'Produkt-Analyse',
              ),
              // const Spacer(),  ← entfernen
            ],
          ),
        ),
        // Content
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildNavButton({
    required String id,
    required IconData icon,
    required String iconName,
    required String label,
    required String tooltip,
  }) {
    final isSelected = _selectedView == id;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: () => setState(() => _selectedView = id),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                getAdaptiveIcon(
                  iconName: iconName,
                  defaultIcon: icon,
                  size: 20,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    // Leerer Filter - zeigt alle Daten
    final emptyFilter = SalesFilter();

    switch (_selectedView) {
      case 'kpi':
        return SalesKpiView(filter: emptyFilter);
      case 'country':
        return SalesCountryView(filter: emptyFilter);
      case 'product':
        return SalesProductView(filter: emptyFilter);
      default:
        return SalesKpiView(filter: emptyFilter);
    }
  }
}