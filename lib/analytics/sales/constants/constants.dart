// lib/screens/analytics/sales/constants/sales_constants.dart

import 'package:flutter/material.dart';

class SalesColors {
  static const Map<String, Color> productColors = {
    'guitar': Color(0xFF1E88E5),    // Blau
    'violin': Color(0xFF43A047),    // Grün
    'cello': Color(0xFFFB8C00),     // Orange
    'viola': Color(0xFF8E24AA),     // Violett
    'bass': Color(0xFF00ACC1),      // Türkis
  };

  static const Map<String, Color> regionColors = {
    'europe': Color(0xFF5C6BC0),    // Indigo
    'asia': Color(0xFFEC407A),      // Pink
    'americas': Color(0xFF26A69A),  // Teal
    'others': Color(0xFF8D6E63),    // Braun
  };

  static Color getProductColor(String product) {
    return productColors[product] ?? Colors.grey;
  }

  static Color getRegionColor(String region) {
    return regionColors[region] ?? Colors.grey;
  }
}

class SalesStrings {
  // Tab Titles
  static const String overviewTab = 'Übersicht';
  static const String salesTab = 'Verkäufe';
  static const String inventoryTab = '';
  static const String customersTab = 'Kunden';
  static const String trendsTab = 'Trends';

  // Section Headers
  static const String salesOverview = 'Verkaufsübersicht';
  static const String revenueAnalysis = 'Umsatzanalyse';
  static const String customerAnalysis = 'Kundenanalyse';
  static const String inventoryStatus = 'Lagerbestand';
  static const String trendAnalysis = 'Trendanalyse';

  // Labels
  static const String totalRevenue = 'Gesamtumsatz';
  static const String totalOrders = 'Anzahl Verkäufe';
  static const String averageOrder = 'Ø Bestellwert';
  static const String activeCustomers = 'Aktive Kunden';
  static const String stockItems = 'Lagerbestand';
  static const String lowStock = 'Niedriger Bestand';
}

class ChartConfig {
  static const double barChartMaxWidth = 60.0;
  static const double pieChartRadius = 110.0;
  static const double pieChartHoleRadius = 40.0;
  static const double minPercentageForLabel = 5.0;

  static const List<Color> defaultColorScheme = [
    Color(0xFF1976D2),  // Blau
    Color(0xFF388E3C),  // Grün
    Color(0xFFF57C00),  // Orange
    Color(0xFF7B1FA2),  // Violett
    Color(0xFF689F38),  // Hellgrün
  ];
}