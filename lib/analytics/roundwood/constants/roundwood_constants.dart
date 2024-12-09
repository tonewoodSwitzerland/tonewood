// lib/screens/analytics/roundwood/constants/roundwood_constants.dart

import 'package:flutter/material.dart';

class RoundwoodColors {
  static const Map<String, Color> qualityColors = {
    'A': Color(0xFF1E88E5),   // Hauptblau
    'AB': Color(0xFF42A5F5),  // Helleres Blau
    'B': Color(0xFF90CAF9),   // Noch helleres Blau
    'BC': Color(0xFF64B5F6),  // Mittleres Blau
    'C': Color(0xFFBBDEFB),   // Sehr helles Blau
  };

  static const Map<String, Color> woodColors = {
    'Fichte': Color(0xFF8D6E63),  // Warmes Braun
    'Tanne': Color(0xFF6D4C41),   // Dunkles Braun
    'Ahorn': Color(0xFFBCAAA4),   // Helles Braun
    'Buche': Color(0xFF795548),   // Mittleres Braun
    'Eiche': Color(0xFF4E342E),   // Sehr dunkles Braun
  };

  static Color getQualityColor(String quality, int index) {
    return qualityColors[quality] ?? Colors.primaries[index % Colors.primaries.length];
  }

  static Color getWoodColor(String woodType, int index) {
    return woodColors[woodType] ?? Colors.primaries[index % Colors.primaries.length];
  }
}

class ChartConfig {
  static const double pieChartRadius = 110;
  static const double pieChartCenterRadius = 40;
  static const double pieChartSectionSpace = 2;
  static const double minPercentageForLabel = 5;
}

class RoundwoodStrings {
  static const String appBarTitle = 'Rundholz Analytics';
  static const String listTabTitle = 'Liste';
  static const String analysisTabTitle = 'Auswertung';

  // Filter-bezogene Strings
  static const String filterTitle = 'Filter';
  static const String woodTypeLabel = 'Holzart';
  static const String qualityLabel = 'Qualität';
  static const String originLabel = 'Herkunft';
  static const String volumeLabel = 'Volumen';
  static const String moonwoodLabel = 'Mondholz';

  // Analyse-bezogene Strings
  static const String totalVolumeLabel = 'Gesamtvolumen';
  static const String totalLogsLabel = 'Anzahl Stämme';
  static const String moonwoodPercentLabel = 'Mondholz Anteil';
  static const String qualityDistributionLabel = 'Qualitätsverteilung';
  static const String woodTypeDistributionLabel = 'Holzartenverteilung';
  static const String volumeTrendLabel = 'Volumenentwicklung';
}