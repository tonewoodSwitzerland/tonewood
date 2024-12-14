// lib/screens/analytics/production/constants/production_constants.dart

import 'package:flutter/material.dart';

class ProductionColors {
  static const Map<String, Color> statusColors = {
    'planned': Color(0xFF90CAF9),    // Hellblau
    'in_progress': Color(0xFFFFF176), // Gelb
    'completed': Color(0xFF81C784),   // Grün
    'delayed': Color(0xFFEF5350),     // Rot
  };

  static const Map<String, Color> instrumentColors = {
    'guitar': Color(0xFF8D6E63),     // Braun
    'violin': Color(0xFF5D4037),     // Dunkelbraun
    'cello': Color(0xFFBC8F8F),      // Rosewood
    'viola': Color(0xFFD2B48C),      // Tan
  };

  static Color getStatusColor(String status) {
    return statusColors[status] ?? Colors.grey;
  }

  static Color getInstrumentColor(String instrument) {
    return instrumentColors[instrument] ?? Colors.grey;
  }
}

class ProductionStrings {
  // Tab Titles
  static const String overviewTab = 'Übersicht';
  static const String specialWoodTab = '';
  static const String efficiencyTab = '';
  static const String fscTab = '';

  // Section Headers
  static const String productionStats = 'Produktionsstatistik';
  static const String batchDistribution = 'Chargengrößen-Verteilung';
  static const String specialWoodAnalysis = 'Spezialholz Analyse';
  static const String efficiencyAnalysis = 'Effizienzanalyse';
  static const String fscAnalysis = 'FSC Analyse';
  // Filter Dialog
  static const String filterTitle = 'Filter';
  static const String filterReset = 'Zurücksetzen';
  static const String filterApply = 'Anwenden';
  // Date Filter
  static const String dateFrom = 'Von';
  static const String dateTo = 'Bis';

  // Status Filter
  static const String statusLabel = 'Status';
  static const String statusAll = 'Alle';
  static const String statusActive = 'Aktiv';
  static const String statusCompleted = 'Abgeschlossen';

  // Type Filter
  static const String typeLabel = 'Produktionsart';
  static const String typeAll = 'Alle';
  static const String typeSawn = 'Schnittholz';
  static const String typeSpecial = 'Spezialholz';

  // Export Dialog
  static const String exportTitle = 'Export';
  static const String exportCancel = 'Abbrechen';
  static const String exportCsv = 'Als CSV exportieren';
  static const String exportCsvSubtitle = 'Tabellarische Daten im CSV-Format';
  static const String exportPdf = 'Als PDF exportieren';
  static const String exportPdfSubtitle = 'Detaillierter Produktionsbericht';
  static const String exportSuccess = 'Export erfolgreich erstellt';
  static const String exportError = 'Fehler beim Export: ';

  // Labels
  static const String totalProducts = 'Produkte gesamt';
  static const String totalBatches = 'Chargen gesamt';
  static const String avgBatchSize = 'Ø Chargengröße';
  static const String efficiency = 'Effizienz';
  static const String haselfichte = 'Haselfichte';
  static const String moonwood = 'Mondholz';
  static const String fscCertified = 'FSC-Zertifiziert';
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