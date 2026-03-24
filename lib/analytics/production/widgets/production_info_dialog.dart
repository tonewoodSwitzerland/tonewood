// lib/analytics/production/widgets/production_info_dialog.dart

import 'package:flutter/material.dart';
import '../../../services/icon_helper.dart';

/// Zeigt eine Erklärung des Produktionsauswertungs-Bereichs.
/// [tab]: 'overview' oder 'logs' – steuert welcher Inhalt gezeigt wird.
/// Auf Mobile: BottomSheet, auf Desktop: großer Dialog.
class ProductionInfoDialog {
  static void show(
      BuildContext context, {
        required bool isDesktop,
        String tab = 'overview',
      }) {
    if (isDesktop) {
      showDialog(
        context: context,
        builder: (context) => _ProductionInfoDesktopDialog(tab: tab),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _ProductionInfoBottomSheet(tab: tab),
      );
    }
  }
}

// ============================================================
// DESKTOP: Großer Dialog
// ============================================================
class _ProductionInfoDesktopDialog extends StatefulWidget {
  final String tab;
  const _ProductionInfoDesktopDialog({required this.tab});

  @override
  State<_ProductionInfoDesktopDialog> createState() =>
      _ProductionInfoDesktopDialogState();
}

class _ProductionInfoDesktopDialogState
    extends State<_ProductionInfoDesktopDialog> {
  bool _expertMode = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLogs = widget.tab == 'logs';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 750),
        child: Column(
          children: [
            _buildHeader(context, theme, isLogs),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                child: _expertMode
                    ? _ExpertModeContent(isLogs: isLogs)
                    : _UserModeContent(isLogs: isLogs),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, bool isLogs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 16, 16),
      decoration: BoxDecoration(
        border:
        Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F4A29).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: getAdaptiveIcon(
              iconName: isLogs ? 'forest' : 'info',
              defaultIcon: isLogs ? Icons.forest : Icons.info,
              color: const Color(0xFF0F4A29),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLogs
                      ? 'Stämme-Ansicht – Erklärung'
                      : 'Produktionsübersicht – Erklärung',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  _expertMode
                      ? 'Technische Details & Datenbanklogik'
                      : 'Wie die Auswertungen zu lesen sind',
                  style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
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
                color: _expertMode
                    ? Colors.deepPurple
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'Experten',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                  _expertMode ? FontWeight.w600 : FontWeight.normal,
                  color: _expertMode
                      ? Colors.deepPurple
                      : theme.colorScheme.onSurfaceVariant,
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
class _ProductionInfoBottomSheet extends StatefulWidget {
  final String tab;
  const _ProductionInfoBottomSheet({required this.tab});

  @override
  State<_ProductionInfoBottomSheet> createState() =>
      _ProductionInfoBottomSheetState();
}

class _ProductionInfoBottomSheetState
    extends State<_ProductionInfoBottomSheet> {
  bool _expertMode = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLogs = widget.tab == 'logs';

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color:
                    theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F4A29).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: getAdaptiveIcon(
                        iconName: isLogs ? 'forest' : 'info',
                        defaultIcon: isLogs ? Icons.forest : Icons.info,
                        color: const Color(0xFF0F4A29),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isLogs
                                ? 'Stämme-Ansicht'
                                : 'Produktionsübersicht',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _expertMode ? 'Technische Details' : 'Erklärung',
                            style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    _buildMobileExpertToggle(theme),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: _expertMode
                      ? _ExpertModeContent(isLogs: isLogs)
                      : _UserModeContent(isLogs: isLogs),
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
            Icon(Icons.code,
                size: 14,
                color: _expertMode
                    ? Colors.deepPurple
                    : theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              'Experten',
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                _expertMode ? FontWeight.w600 : FontWeight.normal,
                color: _expertMode
                    ? Colors.deepPurple
                    : theme.colorScheme.onSurfaceVariant,
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
  final bool isLogs;
  const _UserModeContent({required this.isLogs});

  @override
  Widget build(BuildContext context) {
    return isLogs
        ? _buildLogsContent(context)
        : _buildOverviewContent(context);
  }

  Widget _buildOverviewContent(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildInfoBanner(context,
            icon: Icons.date_range,
            iconName: 'date_range',
            color: Colors.orange,
            title: 'Auf welchen Zeitraum beziehen sich die Daten?',
            text: 'Die Auswertungen beziehen sich immer auf das gewählte '
                'Produktionsjahr – also wann das Holz tatsächlich verarbeitet '
                'und ins Lager gebucht wurde. Das kann vom Stammjahr abweichen: '
                'Ein Stamm aus 2022 kann noch 2024 oder 2025 verarbeitet werden.'),
        const SizedBox(height: 12),
        _buildInfoBanner(context,
            icon: Icons.cached,
            iconName: 'cached',
            color: Colors.blue,
            title: 'Cache & Aktualität',
            text: 'Die Auswertung wird automatisch gecacht. Sobald eine neue '
                'Produktion gebucht wird, berechnet das System beim nächsten '
                'Laden automatisch neu. Das Badge «Cache» oder «Aktuell» '
                'zeigt den Status. Mit dem Refresh-Button kann jederzeit '
                'manuell neu berechnet werden.'),
        const SizedBox(height: 24),
        _buildSectionTitle(context, '📊', 'Zusammenfassung'),
        const SizedBox(height: 12),
        _buildExplanationCard(context, children: [
          _buildKpiExample(context,
              title: 'Gesamtwert',
              exampleValue: 'CHF 248\'500',
              explanation:
              'Summe aller produzierten Artikel im gewählten Jahr, '
                  'bewertet zum Listenpreis (Menge × Preis CHF).'),
          const Divider(height: 24),
          _buildKpiExample(context,
              title: 'Einträge',
              exampleValue: '412',
              explanation: 'Anzahl der Produktionsbuchungen im Jahr. '
                  'Ein Eintrag = ein Buchungsvorgang.'),
          const Divider(height: 24),
          _buildKpiExample(context,
              title: 'Stämme',
              exampleValue: '38',
              explanation:
              'Anzahl verschiedener Stämme aus denen produziert wurde. '
                  'Nur Einträge mit Stamm-Zuordnung.'),
        ]),
        const SizedBox(height: 32),
        _buildSectionTitle(context, '🏆', 'Top 10 Produkte'),
        const SizedBox(height: 12),
        _buildExplanationCard(context, children: [
          Text(
              'Die meistproduzierten Kombinationen aus Instrument und Bauteil, '
                  'sortiert nach Gesamtmenge.',
              style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          _buildBulletPoint(
              context, 'Rang', 'Gold/Silber/Bronze für Platz 1–3.'),
          _buildBulletPoint(
              context, 'Menge', 'Gesamtmenge aller produzierten Einheiten.'),
          _buildBulletPoint(
              context, 'Wert CHF', 'Gesamtwert dieser Kombination.'),
          _buildBulletPoint(
              context, 'Einträge', 'Anzahl der Buchungsvorgänge.'),
        ]),
        const SizedBox(height: 32),
        _buildSectionTitle(context, '⭐', 'Qualitätsverteilung (Decken)'),
        const SizedBox(height: 12),
        _buildExplanationCard(context, children: [
          Text(
              'Für 6 Instrumente: Verteilung der Decken auf Qualitätsstufen '
                  '(MA → AAAA → AAA → AA → A → AB).',
              style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          _buildBulletPoint(
              context, 'Balken', 'Länge proportional zum Anteil.'),
          _buildBulletPoint(
              context, 'Stückzahl', 'Absolute Menge pro Qualitätsstufe.'),
          _buildBulletPoint(
              context, 'Prozent', 'Anteil an der Gesamtproduktion.'),
        ]),
        const SizedBox(height: 32),
        _buildSectionTitle(context, '🌲', 'Produktion nach Holzart'),
        const SizedBox(height: 12),
        _buildExplanationCard(context, children: [
          Text('Alle Holzarten des Jahres, sortiert nach Gesamtwert.',
              style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant)),
        ]),
        const SizedBox(height: 32),
        _buildSectionTitle(context, '📈', 'Durchschnittserlös pro Stamm'),
        const SizedBox(height: 12),
        _buildExplanationCard(context, children: [
          Text(
              'Pro Holzart: durchschnittlicher Produktionswert je Stamm.',
              style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          _buildBulletPoint(context, 'Ø pro Stamm',
              'Gesamtwert ÷ Anzahl Stämme dieser Holzart.'),
          const SizedBox(height: 8),
          _buildInfoBanner(context,
              icon: Icons.info_outline,
              iconName: 'info_outline',
              color: Colors.blue,
              title: 'Nur mit Stamm-Zuordnung',
              text:
              'Buchungen ohne Stamm-Zuordnung werden hier nicht berücksichtigt.'),
        ]),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildLogsContent(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildInfoBanner(context,
            icon: Icons.forest,
            iconName: 'forest',
            color: const Color(0xFF0F4A29),
            title: 'Was zeigt die Stämme-Ansicht?',
            text: 'Alle Stämme des gewählten Jahrgangs – also Stämme deren '
                '«year»-Feld dem gewählten Jahr entspricht. '
                'Dazu werden alle Produktionsbuchungen dieser Stämme angezeigt, '
                'unabhängig davon wann sie verarbeitet wurden.'),
        const SizedBox(height: 24),
        _buildSectionTitle(context, '📊', 'Statistik-Badge'),
        const SizedBox(height: 12),
        _buildExplanationCard(context, children: [
          _buildExampleBox(context,
              'Beispiel: «18/25 Stämme • 412 Einträge»\n'
                  '→ 18 von 25 Stämmen des Jahrgangs haben bereits Produktionsbuchungen.\n'
                  '→ 7 Stämme sind noch nicht verarbeitet worden.'),
          const SizedBox(height: 12),
          _buildBulletPoint(context, 'Zähler links',
              'Stämme mit mindestens einer Buchung / Gesamtanzahl Stämme des Jahrgangs.'),
          _buildBulletPoint(context, 'Einträge',
              'Gesamtanzahl aller Produktionsbuchungen dieser Stämme.'),
        ]),
        const SizedBox(height: 32),
        _buildSectionTitle(context, '👁️', 'Stämme ohne Produktion einblenden'),
        const SizedBox(height: 12),
        _buildExplanationCard(context, children: [
          Text(
              'Falls es Stämme des Jahrgangs gibt die noch nicht verarbeitet wurden, '
                  'erscheint oben rechts ein Button «X ohne Produktion».',
              style: TextStyle(
                  fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          _buildBulletPoint(context, 'Ausgeblendet (Standard)',
              'Nur Stämme mit Buchungen werden angezeigt – übersichtlich.'),
          _buildBulletPoint(context, 'Eingeblendet',
              'Alle Stämme des Jahrgangs werden angezeigt. Stämme ohne Buchungen '
                  'erscheinen ausgegraut mit dem Label «Keine Produktion».'),
        ]),
        const SizedBox(height: 32),
        _buildSectionTitle(context, '🪵', 'Ansicht: Nach Stamm'),
        const SizedBox(height: 12),
        _buildExplanationCard(context, children: [
          Text(
              'Buchungen gruppiert nach Stamm, sortiert nach Stamm-Nummer.',
              style: TextStyle(
                  fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          _buildBulletPoint(context, 'Stamm-Karte',
              'Zeigt Stamm-Nummer/Jahr, Holzart und Gesamtwert aller Buchungen.'),
          _buildBulletPoint(context, 'Aufklappen',
              'Tippe auf eine Karte um alle Einzelbuchungen zu sehen.'),
          _buildBulletPoint(context, 'Tags',
              'Mondholz, FSC und Qualitätsstufe als farbige Tags.'),
          _buildBulletPoint(context, 'Ohne Zuordnung',
              'Buchungen ohne Stamm-Zuordnung erscheinen als eigene Gruppe (oranger Rand).'),
          const SizedBox(height: 12),
          _buildExampleBox(context,
              '🌲 14/2023 – Fichte Alpin · CHF 4\'800 · 6 Einträge\n'
                  '   ↳ 12.03.2024  Steelstring Gitarre Decke  50 Stk\n'
                  '   ↳ 18.03.2024  Klassische Gitarre Decke   40 Stk\n\n'
                  '🌲 15/2023 – Fichte Alpin  [ausgegraut]\n'
                  '   Keine Produktion'),
        ]),
        const SizedBox(height: 32),
        _buildSectionTitle(context, '📅', 'Ansicht: Chronologisch'),
        const SizedBox(height: 12),
        _buildExplanationCard(context, children: [
          Text(
              'Alle Buchungen nach Datum sortiert – neueste zuerst. '
                  'Jede Zeile: Datum, Produkt, Holzart, Qualität, Stamm, Menge, Wert.',
              style: TextStyle(
                  fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          _buildBulletPoint(context, 'Stamm-Badge',
              'Grünes Badge mit Stamm-Nummer falls zugeordnet (z.B. «14/2023»).'),
        ]),
        const SizedBox(height: 32),
        _buildSectionTitle(context, '📤', 'Export'),
        const SizedBox(height: 12),
        _buildExplanationCard(context, children: [
          Text(
              'Über den Download-Button alle Buchungen exportieren.',
              style: TextStyle(
                  fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          _buildBulletPoint(context, 'CSV', 'Tabelle für Excel.'),
          _buildBulletPoint(context, 'PDF Report',
              'Chargenliste mit Zusammenfassung.'),
          _buildBulletPoint(context, 'PDF mit Analyse',
              'Chargenliste + Verteilungsanalyse.'),
        ]),
        const SizedBox(height: 24),
      ],
    );
  }

  // ---- Shared Helpers ----

  static Widget _buildSectionTitle(
      BuildContext context, String emoji, String title) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Text(title,
            style:
            const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  static Widget _buildExplanationCard(BuildContext context,
      {required List<Widget> children}) {
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
            children: children),
      ),
    );
  }

  static Widget _buildKpiExample(BuildContext context,
      {required String title,
        required String exampleValue,
        required String explanation}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(exampleValue,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Text(explanation,
            style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5)),
      ],
    );
  }

  static Widget _buildBulletPoint(
      BuildContext context, String label, String description) {
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
                color: theme.colorScheme.primary, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                    height: 1.4),
                children: [
                  TextSpan(
                      text: '$label: ',
                      style:
                      const TextStyle(fontWeight: FontWeight.w600)),
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
            child: Text(text,
                style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface,
                    height: 1.5)),
          ),
        ],
      ),
    );
  }

  static Widget _buildInfoBanner(BuildContext context,
      {required IconData icon,
        required String iconName,
        required Color color,
        required String title,
        required String text}) {
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
                size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color.withOpacity(0.9))),
                const SizedBox(height: 6),
                Text(text,
                    style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface,
                        height: 1.5)),
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
  final bool isLogs;
  const _ExpertModeContent({required this.isLogs});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildExpertSection(context,
            icon: Icons.storage,
            color: Colors.deepPurple,
            title: 'Datenquelle & Collection',
            children: [
              _buildCodeBlock(context,
                  'Collection:  production_batches\n'
                      'Cache:       production_cache/{year}\n'
                      'Methode:     Future (einmaliger Abruf pro Aufruf)'),
              const SizedBox(height: 12),
              Text(
                  'Alle Daten liegen in der flachen Collection «production_batches». '
                      'Jedes Dokument = ein Buchungsvorgang, denormalisiert.',
                  style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5)),
            ]),
        const SizedBox(height: 20),
        _buildExpertSection(context,
            icon: Icons.cached,
            color: Colors.blue,
            title: 'Cache-Strategie (production_cache)',
            children: [
              _buildCodeBlock(context,
                  '// production_cache/{year}\n'
                      '{\n'
                      '  last_batch_at:          Timestamp, // gesetzt bei createBatch()\n'
                      '  overview_calculated_at: Timestamp,\n'
                      '  logs_calculated_at:     Timestamp,\n'
                      '  overview_data:          Map,\n'
                      '  logs_data:              Map,\n'
                      '}\n\n'
                      '// Prüfung\n'
                      'if (calculated_at >= last_batch_at) → Cache gültig\n'
                      'else → neu berechnen + schreiben\n\n'
                      '// Invalidierung\n'
                      'createBatch() → last_batch_at = serverTimestamp()'),
              const SizedBox(height: 12),
              _buildWarningBox(context,
                  'Übersicht und Stämme haben separate calculated_at-Felder '
                      '(overview_calculated_at / logs_calculated_at) und werden '
                      'unabhängig voneinander gecacht.'),
            ]),
        const SizedBox(height: 20),
        _buildExpertSection(context,
            icon: Icons.filter_alt,
            color: Colors.teal,
            title: 'Firestore Query – Jahr-Filter',
            children: [
              _buildCodeBlock(context,
                  '// Produktionsjahr via stock_entry_date Range\n'
                      '.where(\'stock_entry_date\',\n'
                      '  isGreaterThanOrEqualTo: Timestamp(DateTime(year,1,1)))\n'
                      '.where(\'stock_entry_date\',\n'
                      '  isLessThan: Timestamp(DateTime(year+1,1,1)))\n\n'
                      '// Hinweis: Feld «year» = Stammjahr ≠ Produktionsjahr'),
              const SizedBox(height: 12),
              _buildWarningBox(context,
                  'Composite Index erforderlich. Firebase zeigt beim ersten '
                      'Fehler einen direkten Link zum automatischen Anlegen.'),
            ]),
        const SizedBox(height: 20),
        if (!isLogs)
          _buildExpertSection(context,
              icon: Icons.memory,
              color: Colors.orange,
              title: 'Aggregationen (lokal)',
              children: [
                _buildCodeBlock(context,
                    '_calculateSummary()       → Σ value, Σ qty, unique logs\n'
                        '_calculateTopProducts()   → GROUP BY instrument+part\n'
                        '                            ORDER BY qty DESC, LIMIT 10\n'
                        '_calculateQualityDist()   → part_code=10, 6 Instrumente\n'
                        '_calculateWoodTypeStats() → GROUP BY wood_code\n'
                        '_calculateLogYieldStats() → Ø value / unique logs'),
              ]),
        if (isLogs) ...[
          _buildExpertSection(context,
              icon: Icons.account_tree,
              color: Colors.green,
              title: 'Lade-Logik Stämme-Ansicht',
              children: [
                _buildCodeBlock(context,
                    '// Schritt 1: Alle Stämme des Jahrgangs\n'
                        'roundwood.where("year", == year).get()\n'
                        '→ liefert alle Stamm-IDs + Details\n\n'
                        '// Schritt 2: Batches dieser Stämme\n'
                        'production_batches\n'
                        '  .where("roundwood_id", whereIn: [ids])\n'
                        '  .get()  // chunks à 30 (Firestore-Limit)\n\n'
                        '// Schritt 3: Lokal zusammenführen\n'
                        'for (log in allLogs)\n'
                        '  if (log.id NOT in byLog)\n'
                        '    byLog["_empty_\${log.id}"] = []  // ohne Produktion\n\n'
                        '// Keys:\n'
                        '// "abc123"       → Stamm mit Buchungen\n'
                        '// "_empty_xyz"   → Stamm ohne Buchungen\n'
                        '// "_unassigned"  → Buchungen ohne Stamm'),
                const SizedBox(height: 12),
                _buildWarningBox(context,
                    'whereIn-Limit: Firestore erlaubt max. 30 Werte pro whereIn-Query. '
                        'Bei mehr als 30 Stämmen wird automatisch in Chunks aufgeteilt '
                        '(je 30 IDs = je 1 Firestore-Read).'),
              ]),
        ],
        const SizedBox(height: 20),
        _buildExpertSection(context,
            icon: Icons.article,
            color: Colors.blue,
            title: 'Batch-Dokumentstruktur',
            children: [
              _buildCodeBlock(context,
                  '{\n'
                      '  "stock_entry_date": Timestamp,   // Produktionszeitpunkt\n'
                      '  "year":             2022,         // Stammjahr!\n'
                      '  "roundwood_id":     "abc123",\n'
                      '  "roundwood_internal_number": "14",\n'
                      '  "quantity":         50,\n'
                      '  "unit":             "Stk",\n'
                      '  "price_CHF":        45.00,\n'
                      '  "value":            2250.00,\n'
                      '  "instrument_code":  "10",\n'
                      '  "part_code":        "10",\n'
                      '  "wood_code":        "FI",\n'
                      '  "quality_code":     "AAA",\n'
                      '  "moonwood":         false,\n'
                      '  "FSC_100":          true\n'
                      '}'),
            ]),
        const SizedBox(height: 24),
      ],
    );
  }

  static Widget _buildExpertSection(BuildContext context,
      {required IconData icon,
        required Color color,
        required String title,
        required List<Widget> children}) {
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
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 16),
            ...children,
          ],
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
                : Colors.grey[300]!),
      ),
      child: Text(code,
          style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: theme.brightness == Brightness.dark
                  ? Colors.green[300]
                  : Colors.grey[800],
              height: 1.5)),
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
          Icon(Icons.warning_amber_rounded,
              size: 18, color: Colors.amber[700]),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.5))),
        ],
      ),
    );
  }
}