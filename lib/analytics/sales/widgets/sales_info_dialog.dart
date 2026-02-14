// lib/analytics/sales/widgets/sales_info_dialog.dart

import 'package:flutter/material.dart';
import '../../../services/icon_helper.dart';

/// Zeigt eine umfassende Erklärung des Verkaufsanalyse-Bereichs.
/// Auf Mobile: BottomSheet, auf Desktop: großer Dialog.
class SalesInfoDialog {
  static void show(BuildContext context, {required bool isDesktop}) {
    if (isDesktop) {
      showDialog(
        context: context,
        builder: (context) => const _SalesInfoDesktopDialog(),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const _SalesInfoBottomSheet(),
      );
    }
  }
}

// ============================================================
// DESKTOP: Großer Dialog
// ============================================================
class _SalesInfoDesktopDialog extends StatefulWidget {
  const _SalesInfoDesktopDialog();

  @override
  State<_SalesInfoDesktopDialog> createState() => _SalesInfoDesktopDialogState();
}

class _SalesInfoDesktopDialogState extends State<_SalesInfoDesktopDialog> {
  bool _expertMode = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 750),
        child: Column(
          children: [
            // Header
            _buildHeader(context, theme),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                child: _expertMode
                    ? const _ExpertModeContent()
                    : const _UserModeContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 16, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: getAdaptiveIcon(
              iconName: 'info',
              defaultIcon: Icons.info,
              color: Colors.blue,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Verkaufsanalyse – Erklärung',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  _expertMode
                      ? 'Technische Details & Datenbanklogik'
                      : 'Wie die Auswertungen zu lesen sind',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Expert-Mode Toggle
          _buildExpertToggle(theme),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            tooltip: 'Schließen',
          ),
        ],
      ),
    );
  }

  Widget _buildExpertToggle(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: _expertMode
            ? Colors.deepPurple.withOpacity(0.1)
            : theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: () => setState(() => _expertMode = !_expertMode),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _expertMode ? Icons.code : Icons.code_off,
                size: 16,
                color: _expertMode ? Colors.deepPurple : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'Experten',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: _expertMode ? FontWeight.w600 : FontWeight.normal,
                  color: _expertMode ? Colors.deepPurple : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MOBILE: BottomSheet
// ============================================================
class _SalesInfoBottomSheet extends StatefulWidget {
  const _SalesInfoBottomSheet();

  @override
  State<_SalesInfoBottomSheet> createState() => _SalesInfoBottomSheetState();
}

class _SalesInfoBottomSheetState extends State<_SalesInfoBottomSheet> {
  bool _expertMode = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: getAdaptiveIcon(
                        iconName: 'info',
                        defaultIcon: Icons.info,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Verkaufsanalyse',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _expertMode ? 'Technische Details' : 'Erklärung',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Expert Toggle
                    _buildMobileExpertToggle(theme),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: _expertMode
                      ? const _ExpertModeContent()
                      : const _UserModeContent(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileExpertToggle(ThemeData theme) {
    return GestureDetector(
      onTap: () => setState(() => _expertMode = !_expertMode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _expertMode
              ? Colors.deepPurple.withOpacity(0.1)
              : theme.colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.code,
              size: 14,
              color: _expertMode ? Colors.deepPurple : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              'Experten',
              style: TextStyle(
                fontSize: 11,
                fontWeight: _expertMode ? FontWeight.w600 : FontWeight.normal,
                color: _expertMode ? Colors.deepPurple : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// USER MODE CONTENT
// ============================================================
class _UserModeContent extends StatelessWidget {
  const _UserModeContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        // Datenbasis-Hinweis
        _buildInfoBanner(
          context,
          icon: Icons.date_range,
          iconName: 'date_range',
          color: Colors.orange,
          title: 'Auf welchen Zeitraum beziehen sich die Daten?',
          text: 'Die Auswertungen beziehen sich immer auf alle erfassten '
              'Aufträge in der Datenbank – es gibt keinen festen Stichzeitpunkt. '
              'Die Daten sind live und aktualisieren sich automatisch, '
              'sobald neue Aufträge erfasst oder bestehende geändert werden.\n\n'
              'Zeitvergleiche (z.B. «vs. Vorjahr») beziehen sich immer auf das '
              'aktuelle Kalenderjahr bzw. den aktuellen Kalendermonat im '
              'Vergleich zum vorherigen.',
        ),

        const SizedBox(height: 24),
        _buildSectionTitle(context, '📊', 'Übersicht (KPI)'),
        const SizedBox(height: 12),

        _buildExplanationCard(
          context,
          children: [
            _buildKpiExample(
              context,
              title: 'Umsatz 2026',
              exampleValue: 'CHF 485\'200',
              trend: '+12.3%',
              trendPositive: true,
              explanation: 'Gesamtumsatz aller Aufträge im aktuellen Kalenderjahr '
                  '(1. Januar bis heute). Der Vergleichswert «vs. Vorjahr» zeigt '
                  'die prozentuale Veränderung gegenüber dem gleichen Zeitraum '
                  'des Vorjahres.',
            ),
            const Divider(height: 24),
            _buildKpiExample(
              context,
              title: 'Umsatz Februar',
              exampleValue: 'CHF 38\'750',
              trend: '-5.2%',
              trendPositive: false,
              explanation: 'Umsatz im aktuellen Kalendermonat. Der Vergleich '
                  '«vs. Vormonat» zeigt die Veränderung gegenüber dem gesamten '
                  'Vormonat. Tipp: Tippe auf die Karte, um den monatlichen '
                  'Umsatzverlauf der letzten 12 Monate als Balkendiagramm zu sehen.',
            ),
            const Divider(height: 24),
            _buildKpiExample(
              context,
              title: 'Anzahl Verkäufe',
              exampleValue: '127',
              trend: null,
              trendPositive: null,
              explanation: 'Gesamtzahl aller Aufträge (ohne stornierte). '
                  'Ein Auftrag kann mehrere Positionen enthalten.',
            ),
            const Divider(height: 24),
            _buildKpiExample(
              context,
              title: 'Ø Erlös / Verkauf',
              exampleValue: 'CHF 3\'820',
              trend: null,
              trendPositive: null,
              explanation: 'Durchschnittlicher Umsatz pro Auftrag. '
                  'Berechnung: Gesamtumsatz ÷ Anzahl Aufträge.',
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Thermobehandlung
        _buildExplanationCard(
          context,
          children: [
            _buildSubSectionHeader(context, Icons.whatshot, Colors.deepOrange, 'Thermobehandlung'),
            const SizedBox(height: 12),
            Text(
              'Zeigt den Anteil der thermobehandelten Artikel:',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            _buildBulletPoint(context, 'Anteil Artikel',
                'Wie viele der verkauften Positionen eine Thermobehandlung haben '
                    '(z.B. 45 von 312 = 14.4%).'),
            _buildBulletPoint(context, 'Anteil Umsatz',
                'Wie viel des Gesamtumsatzes auf thermobehandelte Artikel entfällt.'),
            const SizedBox(height: 8),
            _buildExampleBox(context,
                'Beispiel: 14.4% der Artikel sind thermobehandelt und '
                    'machen CHF 72\'300 (15.1%) des Umsatzes aus.'),
          ],
        ),

        const SizedBox(height: 32),
        _buildSectionTitle(context, '🌍', 'Länder-Analyse'),
        const SizedBox(height: 12),

        _buildExplanationCard(
          context,
          children: [
            Text(
              'Die Länder-Analyse zeigt, wohin Lieferungen gehen und '
                  'wie sich der Umsatz auf verschiedene Länder verteilt.',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 16),
            _buildSubSectionHeader(context, Icons.public, Colors.teal, 'Kopfzeile'),
            const SizedBox(height: 8),
            _buildBulletPoint(context, 'Anzahl Länder',
                'In wie viele verschiedene Länder geliefert wurde.'),
            _buildBulletPoint(context, 'Lieferungen',
                'Gesamtanzahl aller Aufträge mit Länderzuordnung.'),
            const SizedBox(height: 16),
            _buildSubSectionHeader(context, Icons.pie_chart, Colors.blue, 'Kreisdiagramm'),
            const SizedBox(height: 8),
            Text(
              'Zeigt die Top 6 Länder nach Umsatz. Alle weiteren Länder werden unter «Andere» zusammengefasst. '
                  'Die Prozentzahlen im Diagramm zeigen den Umsatzanteil jedes Landes.',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            _buildSubSectionHeader(context, Icons.table_chart, Colors.indigo, 'Länder-Tabelle'),
            const SizedBox(height: 8),
            Text(
              'Detaillierte Auflistung der Top 15 Länder mit:',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
            ),
            _buildBulletPoint(context, 'Umsatz', 'Absoluter Umsatz in CHF.'),
            _buildBulletPoint(context, '%', 'Prozentualer Anteil am Gesamtumsatz.'),
            _buildBulletPoint(context, 'Lfg.', 'Anzahl Lieferungen in dieses Land.'),
            const SizedBox(height: 8),
            Text(
              'Die Sortierung kann zwischen Umsatz und Lieferungen umgeschaltet werden.',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 12),
            _buildExampleBox(context,
                'Beispiel: 🇩🇪 Deutschland – CHF 152\'400 (31.4%) – 42 Lieferungen\n'
                    '🇦🇹 Österreich – CHF 89\'100 (18.4%) – 28 Lieferungen\n'
                    '🇫🇷 Frankreich – CHF 67\'800 (14.0%) – 19 Lieferungen'),
          ],
        ),

        const SizedBox(height: 32),
        _buildSectionTitle(context, '🎸', 'Produkt-Analyse'),
        const SizedBox(height: 12),

        _buildExplanationCard(
          context,
          children: [
            _buildSubSectionHeader(context, Icons.emoji_events, Colors.indigo, 'Top 10 Produkte'),
            const SizedBox(height: 8),
            Text(
              'Die meistverkauften Kombination aus Instrument und Bauteil, '
                  'sortiert nach Umsatz. Jeder Eintrag zeigt:',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
            ),
            _buildBulletPoint(context, 'Rang', 'Gold/Silber/Bronze für Platz 1–3.'),
            _buildBulletPoint(context, 'Produktname',
                'Kombination aus Instrument und Bauteil (z.B. «Steelstring Gitarre – Decke»).'),
            _buildBulletPoint(context, 'Stück', 'Gesamtmenge aller verkauften Einheiten.'),
            _buildBulletPoint(context, 'Umsatz', 'Gesamtumsatz dieser Kombination.'),
            _buildBulletPoint(context, 'Balken',
                'Visueller Vergleich – der Balken zeigt den Umsatz relativ zum Top-Produkt.'),
            const SizedBox(height: 12),
            _buildExampleBox(context,
                'Beispiel:\n'
                    '🥇 Steelstring Gitarre – Decke: 234 Stück, CHF 98\'500\n'
                    '🥈 Klassische Gitarre – Boden/Zargen: 189 Stück, CHF 76\'200\n'
                    '🥉 Ukulele – Set: 156 Stück, CHF 45\'900'),
            const SizedBox(height: 20),
            _buildSubSectionHeader(context, Icons.forest, Colors.brown, 'Umsatz nach Holzart'),
            const SizedBox(height: 8),
            Text(
              'Zeigt, welche Holzarten den meisten Umsatz generieren:',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
            ),
            _buildBulletPoint(context, 'Kreisdiagramm',
                'Top 6 Holzarten visuell dargestellt, Rest als «Andere».'),
            _buildBulletPoint(context, 'Liste',
                'Top 10 Holzarten mit Stückzahl, Prozentanteil und Umsatz.'),
            const SizedBox(height: 12),
            _buildExampleBox(context,
                'Beispiel:\n'
                    '● Fichte Alpin: 420 Stk – 35.2% – CHF 170\'400\n'
                    '● Palisander: 185 Stk – 22.8% – CHF 110\'300\n'
                    '● Ahorn: 210 Stk – 15.4% – CHF 74\'600'),
          ],
        ),

        const SizedBox(height: 32),
        _buildSectionTitle(context, '🔍', 'Filter'),
        const SizedBox(height: 12),

        _buildExplanationCard(
          context,
          children: [
            Text(
              'Alle Ansichten können mit folgenden Filtern eingeschränkt werden:',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 12),
            _buildFilterItem(context, 'Kunden', 'Nur Aufträge bestimmter Kunden anzeigen.'),
            _buildFilterItem(context, 'Messen', 'Nur Aufträge die einer bestimmten Messe zugeordnet sind.'),
            _buildFilterItem(context, 'Holzarten', 'Nur Positionen mit bestimmten Holzarten.'),
            _buildFilterItem(context, 'Qualitäten', 'Nur Positionen bestimmter Qualitätsstufen.'),
            _buildFilterItem(context, 'Bauteile', 'Nur bestimmte Bauteile (z.B. Decke, Boden).'),
            _buildFilterItem(context, 'Instrumente', 'Nur bestimmte Instrumente (z.B. Gitarre, Ukulele).'),
            _buildFilterItem(context, 'Produkte', 'Nur bestimmte Produkte.'),
            _buildFilterItem(context, 'Betrag', 'Nur Aufträge mit Mindestumsatz / Maximalumsatz.'),
            const SizedBox(height: 12),
            _buildExampleBox(context,
                'Tipp: Filter werden gleichzeitig auf alle drei Ansichten '
                    '(Übersicht, Länder, Produkte) angewendet. So können Sie z.B. '
                    'sehen, in welche Länder Fichtendecken geliefert wurden.'),
          ],
        ),

        const SizedBox(height: 32),

        // Stornierte Aufträge Hinweis
        _buildInfoBanner(
          context,
          icon: Icons.block,
          iconName: 'block',
          color: Colors.red,
          title: 'Stornierte Aufträge',
          text: 'Aufträge mit dem Status «storniert» werden in keiner '
              'Auswertung berücksichtigt. Sie erscheinen weder in den '
              'Umsatzzahlen noch in der Länderzuordnung oder Produktstatistik.',
        ),

        const SizedBox(height: 16),

        // Währung
        _buildInfoBanner(
          context,
          icon: Icons.payments,
          iconName: 'payments',
          color: Colors.green,
          title: 'Währung & Beträge',
          text: 'Alle Beträge werden in Schweizer Franken (CHF) angezeigt. '
              'Die Umsätze basieren auf dem Netto-Preis pro Einheit '
              'multipliziert mit der bestellten Menge (Stückpreis × Menge).',
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // ---- Helper Widgets ----

  static Widget _buildSectionTitle(BuildContext context, String emoji, String title) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  static Widget _buildExplanationCard(BuildContext context, {required List<Widget> children}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  static Widget _buildSubSectionHeader(BuildContext context, IconData icon, Color color, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  static Widget _buildKpiExample(
      BuildContext context, {
        required String title,
        required String exampleValue,
        required String? trend,
        required bool? trendPositive,
        required String explanation,
      }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mini-Preview der KPI-Karte
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      exampleValue,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (trendPositive == true ? Colors.green : Colors.red).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trendPositive == true ? Icons.trending_up : Icons.trending_down,
                        size: 14,
                        color: trendPositive == true ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        trend,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: trendPositive == true ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          explanation,
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  static Widget _buildBulletPoint(BuildContext context, String label, String description) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildFilterItem(BuildContext context, String name, String description) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.filter_list, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface, height: 1.4),
                children: [
                  TextSpan(text: '$name – ', style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildExampleBox(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, size: 18, color: Colors.blue[600]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildInfoBanner(
      BuildContext context, {
        required IconData icon,
        required String iconName,
        required Color color,
        required String title,
        required String text,
      }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: getAdaptiveIcon(
              iconName: iconName,
              defaultIcon: icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// EXPERT MODE CONTENT
// ============================================================
class _ExpertModeContent extends StatelessWidget {
  const _ExpertModeContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        // Datenquelle
        _buildExpertSection(
          context,
          icon: Icons.storage,
          color: Colors.deepPurple,
          title: 'Datenquelle & Abfrage',
          children: [
            _buildCodeBlock(context,
                'Collection: orders\n'
                    'Quelle:     Firestore (Cloud Firestore)\n'
                    'Methode:    Real-time Stream (snapshots)'),
            const SizedBox(height: 12),
            Text(
              'Alle Daten werden direkt aus der Firestore-Collection «orders» '
                  'gelesen. Es wird ein Echtzeit-Stream verwendet – Änderungen an '
                  'Dokumenten werden sofort reflektiert.',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant, height: 1.5),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Firestore Query-Filter
        _buildExpertSection(
          context,
          icon: Icons.filter_alt,
          color: Colors.teal,
          title: 'Firestore Query-Filter (serverseitig)',
          children: [
            Text(
              'Die folgenden Filter werden direkt als Firestore-Query angewendet '
                  '(serverseitig, bevor die Daten zum Client kommen):',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 12),
            _buildCodeBlock(context,
                '// Kundenfilter\n'
                    'if (filter.selectedCustomers != null)\n'
                    '  query.where(\'customer.id\', whereIn: [...])\n'
                    '\n'
                    '// Messefilter\n'
                    'if (filter.selectedFairs != null)\n'
                    '  query.where(\'fair.id\', whereIn: [...])'),
            const SizedBox(height: 12),
            _buildWarningBox(context,
                'Einschränkung: Firestore erlaubt nur einen «whereIn»-Filter '
                    'pro Query. Kunden- und Messefilter können daher nicht '
                    'gleichzeitig serverseitig gefiltert werden. In der Praxis '
                    'wird einer serverseitig und der andere clientseitig angewendet.'),
          ],
        ),

        const SizedBox(height: 20),

        // Client-seitige Verarbeitung
        _buildExpertSection(
          context,
          icon: Icons.memory,
          color: Colors.orange,
          title: 'Client-seitige Verarbeitung',
          children: [
            Text(
              'Die folgenden Filter und Berechnungen erfolgen clientseitig '
                  'nach dem Laden der Daten:',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 12),
            _buildCodeBlock(context,
                'Pro Order-Dokument:\n'
                    '1. orderDate parsen (Timestamp oder String)\n'
                    '2. Status prüfen → cancelled überspringen\n'
                    '3. items[] durchlaufen:\n'
                    '   → Item-Filter prüfen (Holzart, Qualität, Bauteil,\n'
                    '     Instrument, Produkt)\n'
                    '   → itemRevenue = quantity × price_per_unit\n'
                    '   → Aggregation: Holzart, Produkt-Kombis, Thermo\n'
                    '4. Betrags-Filter (min/max) auf Order-Ebene\n'
                    '5. Zeitraum-Zuordnung:\n'
                    '   → Aktuelles Jahr / Monat\n'
                    '   → Vorjahr / Vormonat\n'
                    '   → Monatliche Buckets (YYYY-MM)'),
          ],
        ),

        const SizedBox(height: 20),

        // Datenstruktur
        _buildExpertSection(
          context,
          icon: Icons.account_tree,
          color: Colors.blue,
          title: 'Order-Dokumentstruktur (Firestore)',
          children: [
            _buildCodeBlock(context,
                '{\n'
                    '  "orderDate": Timestamp | String,\n'
                    '  "status": "active" | "cancelled" | ...,\n'
                    '  "customer": {\n'
                    '    "id": "cust_001",\n'
                    '    "countryCode": "DE",\n'
                    '    "country": "Deutschland"\n'
                    '  },\n'
                    '  "fair": {\n'
                    '    "id": "fair_001"\n'
                    '  },\n'
                    '  "items": [\n'
                    '    {\n'
                    '      "product_id": "prod_001",\n'
                    '      "wood_code": "FI",\n'
                    '      "wood_name": "Fichte Alpin",\n'
                    '      "quality_code": "AAA",\n'
                    '      "instrument_code": "SG",\n'
                    '      "instrument_name": "Steelstring Gitarre",\n'
                    '      "part_code": "DE",\n'
                    '      "part_name": "Decke",\n'
                    '      "has_thermal_treatment": true,\n'
                    '      "quantity": 10,\n'
                    '      "price_per_unit": 45.00\n'
                    '    }\n'
                    '  ]\n'
                    '}'),
          ],
        ),

        const SizedBox(height: 20),

        // Berechnungslogik
        _buildExpertSection(
          context,
          icon: Icons.calculate,
          color: Colors.green,
          title: 'Berechnungslogik im Detail',
          children: [
            _buildExpertSubSection(context, 'Umsatzberechnung'),
            _buildCodeBlock(context,
                'itemRevenue = item.quantity × item.price_per_unit\n'
                    'orderRevenue = Σ itemRevenue (nur matching items)\n'
                    'totalRevenue = Σ orderRevenue (alle Orders)'),
            const SizedBox(height: 16),
            _buildExpertSubSection(context, 'Zeitraum-Vergleiche'),
            _buildCodeBlock(context,
                'currentYearStart  = 1. Januar aktuelles Jahr\n'
                    'previousYearStart = 1. Januar Vorjahr\n'
                    'previousYearEnd   = 31. Dezember Vorjahr 23:59:59\n'
                    '\n'
                    'yearRevenue: orderDate >= currentYearStart\n'
                    'previousYearRevenue: previousYearStart < orderDate\n'
                    '                     < previousYearEnd\n'
                    '\n'
                    'yearChangePercent =\n'
                    '  (yearRevenue - previousYearRevenue)\n'
                    '  / previousYearRevenue × 100\n'
                    '\n'
                    '⚠️ Vergleicht aktuelles Jahr (bis heute)\n'
                    '   mit dem GESAMTEN Vorjahr!'),
            const SizedBox(height: 8),
            _buildWarningBox(context,
                'Hinweis: Der Vorjahresvergleich vergleicht den bisherigen '
                    'Umsatz des aktuellen Jahres mit dem gesamten Vorjahr. '
                    'Anfang des Jahres wird der Vergleichswert daher immer '
                    'stark negativ sein. Ein fairer Vergleich zum gleichen '
                    'Zeitpunkt des Vorjahres ist aktuell nicht implementiert.'),
            const SizedBox(height: 16),
            _buildExpertSubSection(context, 'Monatliche Zuordnung'),
            _buildCodeBlock(context,
                'monthKey = "\${orderDate.year}-\${orderDate.month\n'
                    '           .toString().padLeft(2, \'0\')}"\n'
                    '// z.B. "2026-02"\n'
                    '\n'
                    'monthlyRevenue[monthKey] += orderRevenue'),
            const SizedBox(height: 16),
            _buildExpertSubSection(context, 'Länder-Zuordnung'),
            _buildCodeBlock(context,
                'countryCode = customer.countryCode\n'
                    '           ?? customer.country\n'
                    '           ?? "XX"\n'
                    '\n'
                    'country = Countries.getCountryByCode(countryCode)\n'
                    '→ Aggregation pro countryCode:\n'
                    '   revenue, orderCount, itemCount'),
            const SizedBox(height: 16),
            _buildExpertSubSection(context, 'Produkt-Kombinationen'),
            _buildCodeBlock(context,
                'comboKey = "\${instrumentCode}_\${partCode}"\n'
                    '→ z.B. "SG_DE" = Steelstring Gitarre Decke\n'
                    '\n'
                    'Aggregation: revenue, quantity\n'
                    'Sortierung: nach revenue DESC\n'
                    'Limit: Top 10'),
            const SizedBox(height: 16),
            _buildExpertSubSection(context, 'Thermo-Statistik'),
            _buildCodeBlock(context,
                'if (item.has_thermal_treatment == true)\n'
                    '  thermoItemCount++\n'
                    '  thermoRevenue += itemRevenue\n'
                    '\n'
                    'itemSharePercent = thermoItemCount\n'
                    '                   / totalItemCount × 100\n'
                    'revenueSharePercent = thermoRevenue\n'
                    '                     / totalRevenue × 100'),
          ],
        ),

        const SizedBox(height: 20),

        // Item-Filter Logik
        _buildExpertSection(
          context,
          icon: Icons.rule,
          color: Colors.red,
          title: 'Item-Filter Logik (_itemMatchesFilter)',
          children: [
            Text(
              'Jeder Item-Filter ist ein UND-Filter – alle gesetzten Filter '
                  'müssen zutreffen. Innerhalb eines Filters (z.B. mehrere '
                  'Holzarten) gilt ODER.',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 12),
            _buildCodeBlock(context,
                'Filter-Kette (alle müssen passen):\n'
                    '├── woodTypes?     → item.wood_code ∈ filter\n'
                    '├── qualities?     → item.quality_code ∈ filter\n'
                    '├── parts?         → item.part_code ∈ filter\n'
                    '├── instruments?   → item.instrument_code ∈ filter\n'
                    '└── products?      → item.product_id ∈ filter\n'
                    '\n'
                    'Danach auf Order-Ebene:\n'
                    '├── minAmount?     → orderRevenue >= minAmount\n'
                    '└── maxAmount?     → orderRevenue <= maxAmount'),
            const SizedBox(height: 12),
            _buildWarningBox(context,
                'Wichtig: Der Betragsfilter (min/max) bezieht sich auf den '
                    'Umsatz der gefilterten Items pro Order, nicht auf den '
                    'Gesamtauftragswert. Wenn z.B. nur Holzart «Fichte» '
                    'gefiltert wird, zählt nur der Fichte-Umsatz des Auftrags.'),
          ],
        ),

        const SizedBox(height: 20),

        // Performance-Hinweise
        _buildExpertSection(
          context,
          icon: Icons.speed,
          color: Colors.amber,
          title: 'Performance & Limitierungen',
          children: [
            _buildExpertBullet(context, 'Gesamtlast',
                'Alle Orders werden geladen und clientseitig verarbeitet. '
                    'Bei sehr vielen Orders (>10\'000) kann dies zu Ladezeiten führen.'),
            _buildExpertBullet(context, 'Kein Date-Range auf Server',
                'Der Datumsfilter (startDate/endDate) aus SalesFilter wird '
                    'aktuell NICHT auf die Firestore-Query angewendet. Alle '
                    'Dokumente werden geladen.'),
            _buildExpertBullet(context, 'Neue Service-Instanz',
                'Jeder View erstellt eine eigene SalesAnalyticsService-Instanz. '
                    'Bei Tab-Wechsel wird der Stream neu aufgebaut.'),
            _buildExpertBullet(context, 'Keine Caching-Strategie',
                'Es gibt kein explizites Caching – Firestore SDK nutzt jedoch '
                    'seinen internen Cache.'),
          ],
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // ---- Expert Helper Widgets ----

  static Widget _buildExpertSection(
      BuildContext context, {
        required IconData icon,
        required Color color,
        required String title,
        required List<Widget> children,
      }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  static Widget _buildExpertSubSection(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  static Widget _buildCodeBlock(BuildContext context, String code) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Colors.grey[900]
            : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.grey[700]!
              : Colors.grey[300]!,
        ),
      ),
      child: Text(
        code,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: theme.brightness == Brightness.dark
              ? Colors.green[300]
              : Colors.grey[800],
          height: 1.5,
        ),
      ),
    );
  }

  static Widget _buildWarningBox(BuildContext context, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: Colors.amber[700]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildExpertBullet(BuildContext context, String label, String description) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.arrow_right, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface, height: 1.5),
                children: [
                  TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}