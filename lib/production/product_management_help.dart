// ═══════════════════════════════════════════════════════════════════════════
// lib/production/product_management_help.dart
//
// Zentrale Hilfe / Onboarding für die Produktverwaltung.
// Gibt neuen Usern einen schnellen Überblick über alle Funktionalitäten.
//
// Aufruf von überall:
//   showProductManagementHelp(
//     context: context,
//     topic: ProductHelpTopic.produktionBuchen,
//   );
//
// - Mobile (< 600px): wird als Bottom Sheet angezeigt
// - Web / Desktop:    wird als breiter, zentrierter Dialog angezeigt
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../services/icon_helper.dart';

/// Die vier Bereiche der Produktverwaltung. [overview] zeigt alles ohne
/// Hervorhebung – ideal als allgemeiner Einstieg.
enum ProductHelpTopic {
  overview,
  produktionBuchen,
  ueberStamm,
  produkte,
  rundholz,
}

/// Haupt-Akzentfarbe der Produktverwaltung.
const Color _kAccent = Color(0xFF0F4A29);

/// Öffnet die Hilfe zur Produktverwaltung.
///
/// Auf Mobilgeräten als Bottom Sheet, auf Web/Desktop als breiter Dialog.
/// Über [topic] wird der passende Bereich nach oben sortiert und hervorgehoben,
/// die übrigen Bereiche bleiben darunter sichtbar (Gesamtüberblick).
Future<void> showProductManagementHelp({
  required BuildContext context,
  ProductHelpTopic topic = ProductHelpTopic.overview,
}) {
  final isMobile = MediaQuery.of(context).size.width < 600;

  if (isMobile) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProductHelpContent(topic: topic, isMobile: true),
    );
  }

  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 760),
        child: _ProductHelpContent(topic: topic, isMobile: false),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Datenmodell für die Hilfe-Inhalte
// ═══════════════════════════════════════════════════════════════════════════

class _HelpItem {
  final String iconName;
  final IconData icon;
  final String title;
  final String text;

  const _HelpItem({
    required this.iconName,
    required this.icon,
    required this.title,
    required this.text,
  });
}

class _HelpSection {
  final ProductHelpTopic topic;
  final String iconName;
  final IconData icon;
  final String title;
  final String summary;
  final List<_HelpItem> items;
  final String? note;

  const _HelpSection({
    required this.topic,
    required this.iconName,
    required this.icon,
    required this.title,
    required this.summary,
    required this.items,
    this.note,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// Inhalte (an einer Stelle pflegbar)
// ═══════════════════════════════════════════════════════════════════════════

const String _kIntro =
    'Die Produktverwaltung bündelt alles rund um deine Produkte: Du buchst '
    'fertige Produktion in den Lagerbestand, legst Produkte an oder bearbeitest '
    'sie und pflegst deine Rundholz-Stämme. Hier findest du einen kompakten '
    'Überblick über die vier Bereiche.';

const List<_HelpSection> _kSections = [
  // ─── 1. Produktion buchen ───────────────────────────────────────────────
  _HelpSection(
    topic: ProductHelpTopic.produktionBuchen,
    iconName: 'precision_manufacturing',
    icon: Icons.precision_manufacturing,
    title: 'Produktion buchen',
    summary: 'Fertige Produktion als Wareneingang in den Lagerbestand buchen.',
    items: [
      _HelpItem(
        iconName: 'search',
        icon: Icons.search,
        title: 'Suchen',
        text: 'Produkt aus der Produktionsliste auswählen und die produzierte '
            'Menge buchen.',
      ),
      _HelpItem(
        iconName: 'qr_code_scanner',
        icon: Icons.qr_code_scanner,
        title: 'Scannen',
        text: 'Produktions-Barcode mit der Kamera scannen – das Produkt wird '
            'automatisch gefunden.',
      ),
      _HelpItem(
        iconName: 'dialpad',
        icon: Icons.dialpad,
        title: 'Eingabe',
        text: 'Barcode Stelle für Stelle über das Nummernfeld eingeben, falls '
            'kein Scanner zur Hand ist.',
      ),
      _HelpItem(
        iconName: 'account_tree',
        icon: Icons.account_tree,
        title: 'Über Stamm',
        text: 'Buchung ausgehend von einem Rundholz-Stamm – Details im eigenen '
            'Bereich weiter unten.',
      ),
      _HelpItem(
        iconName: 'history',
        icon: Icons.history,
        title: 'Letzter Stamm',
        text: 'Springt direkt in die zuletzt bearbeitete, noch offene '
            'Stamm-Buchung.',
      ),
    ],
    note: 'Barcode-Format: Produktion = IIPP.HHQQ.EEEE.JJ (14 Stellen). Ein '
        'Verkaufs-Barcode (nur IIPP.HHQQ, 8 Stellen) wird hier abgelehnt. Jede '
        'Buchung legt eine Charge an und erhöht den Bestand in Produktion und '
        'Inventar.',
  ),

  // ─── 2. Über Stamm buchen ───────────────────────────────────────────────
  _HelpSection(
    topic: ProductHelpTopic.ueberStamm,
    iconName: 'account_tree',
    icon: Icons.account_tree,
    title: 'Über Stamm buchen',
    summary: 'Produktion direkt einem konkreten Rundholz-Stamm zuordnen.',
    items: [
      _HelpItem(
        iconName: 'forest',
        icon: Icons.forest,
        title: 'Stamm wählen',
        text: 'Zuerst den passenden Stamm aus der Liste auswählen.',
      ),
      _HelpItem(
        iconName: 'auto_awesome',
        icon: Icons.auto_awesome,
        title: 'Attribute automatisch',
        text: 'Holzart, Mondholz, Haselfichte, FSC und Jahr werden vom Stamm '
            'übernommen – kein doppeltes Eintippen.',
      ),
      _HelpItem(
        iconName: 'link',
        icon: Icons.link,
        title: 'Rückverfolgbar',
        text: 'Jede Charge erhält die Stamm-Referenz. So bleibt nachvollziehbar, '
            'aus welchem Stamm ein Produkt stammt.',
      ),
    ],
    note: 'Über „Letzter Stamm" kommst du jederzeit zurück zur zuletzt offenen '
        'Buchung.',
  ),

  // ─── 3. Produkte verwalten ──────────────────────────────────────────────
  _HelpSection(
    topic: ProductHelpTopic.produkte,
    iconName: 'inventory_2',
    icon: Icons.inventory_2,
    title: 'Produkte verwalten',
    summary: 'Produkte neu anlegen oder bestehende bearbeiten.',
    items: [
      _HelpItem(
        iconName: 'edit',
        icon: Icons.edit,
        title: 'Bearbeiten',
        text: 'Produkt per Barcode-Eingabe oder Scan suchen und Eigenschaften '
            'anpassen.',
      ),
      _HelpItem(
        iconName: 'qr_code_scanner',
        icon: Icons.qr_code_scanner,
        title: 'Scannen',
        text: 'Barcode scannen, um direkt zum passenden Produkt zu springen.',
      ),
      _HelpItem(
        iconName: 'add_circle',
        icon: Icons.add_circle,
        title: 'Neu anlegen',
        text: 'Neues Produkt aus Instrument, Bauteil, Holzart, Qualität und '
            'Eigenschaften zusammenstellen.',
      ),
    ],
    note: 'Achtung: Wird eine Eigenschaft (Thermo, Haselfichte, Mondholz, FSC) '
        'oder das Jahr geändert, entsteht eine neue Produktions-ID. Bestehende '
        'Chargen werden übertragen und die Bestände aktualisiert – dieser '
        'Schritt lässt sich nicht rückgängig machen.',
  ),

  // ─── 4. Rundholz ────────────────────────────────────────────────────────
  _HelpSection(
    topic: ProductHelpTopic.rundholz,
    iconName: 'forest',
    icon: Icons.forest,
    title: 'Rundholz',
    summary: 'Rundholz-Stämme erfassen und verwalten.',
    items: [
      _HelpItem(
        iconName: 'add_circle',
        icon: Icons.add_circle,
        title: 'Neues Rundholz',
        text: 'Einen neuen Stamm mit seinen Stammdaten anlegen.',
      ),
      _HelpItem(
        iconName: 'forest',
        icon: Icons.forest,
        title: 'Stämme verwalten',
        text: 'Bestehende Stämme einsehen und bearbeiten.',
      ),
      _HelpItem(
        iconName: 'check_circle',
        icon: Icons.check_circle,
        title: 'Offen & abgeschlossen',
        text: 'Offene Stämme können bebucht und – wenn fertig – abgeschlossen '
            'werden.',
      ),
    ],
  ),
];

// ═══════════════════════════════════════════════════════════════════════════
// Inhalts-Widget (gemeinsam für Sheet & Dialog)
// ═══════════════════════════════════════════════════════════════════════════

class _ProductHelpContent extends StatelessWidget {
  final ProductHelpTopic topic;
  final bool isMobile;

  const _ProductHelpContent({
    required this.topic,
    required this.isMobile,
  });

  /// Im Einzelmodus (topic != overview) der passende Abschnitt, sonst null.
  _HelpSection? get _activeSection {
    if (topic == ProductHelpTopic.overview) return null;
    for (final s in _kSections) {
      if (s.topic == topic) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
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
            _buildHeader(context),
            Expanded(child: _buildBody(padding: 16)),
          ],
        ),
      );
    }

    // Desktop / Web
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(context),
        Flexible(child: _buildBody(padding: 32)),
      ],
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    final section = _activeSection;
    final headerIconName = section?.iconName ?? 'help_outline';
    final headerIcon = section?.icon ?? Icons.help_outline;
    final headerTitle = section?.title ?? 'Produktverwaltung';
    final headerSubtitle =
    section != null ? 'Produktverwaltung' : 'Funktionen im Überblick';

    return Container(
      padding: EdgeInsets.fromLTRB(isMobile ? 16 : 32, isMobile ? 12 : 24, 12, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: getAdaptiveIcon(
              iconName: headerIconName,
              defaultIcon: headerIcon,
              color: _kAccent,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headerTitle,
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: _kAccent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  headerSubtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Schließen',
            icon: getAdaptiveIcon(
              iconName: 'close',
              defaultIcon: Icons.close,
              color: Colors.grey[600],
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // ─── Body ─────────────────────────────────────────────────────────────
  Widget _buildBody({required double padding}) {
    final section = _activeSection;

    // Einzelmodus: nur den Abschnitt der jeweiligen Unterseite erklären.
    if (section != null) {
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kurzbeschreibung des Bereichs
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kAccent.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kAccent.withOpacity(0.15)),
              ),
              child: Text(
                section.summary,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.grey[800],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Funktionen dieses Bereichs
            for (int i = 0; i < section.items.length; i++) ...[
              _buildItemRow(section.items[i]),
              if (i < section.items.length - 1) const SizedBox(height: 14),
            ],

            // Hinweis
            if (section.note != null) ...[
              const SizedBox(height: 20),
              _buildNote(section.note!),
            ],
          ],
        ),
      );
    }

    // Überblick: alle Bereiche.
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Intro
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kAccent.withOpacity(0.15)),
            ),
            child: Text(
              _kIntro,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.grey[800],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Bereiche
          for (final s in _kSections) ...[
            _buildSectionCard(s, highlighted: false),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  // ─── Hinweis-Box ────────────────────────────────────────────────────────
  Widget _buildNote(String note) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          getAdaptiveIcon(
            iconName: 'info_outline',
            defaultIcon: Icons.info_outline,
            color: Colors.amber[800],
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              note,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: Colors.brown[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section-Karte ──────────────────────────────────────────────────────
  Widget _buildSectionCard(_HelpSection section, {required bool highlighted}) {
    return Container(
      decoration: BoxDecoration(
        color: highlighted ? _kAccent.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted ? _kAccent.withOpacity(0.5) : Colors.grey.shade300,
          width: highlighted ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section-Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: getAdaptiveIcon(
                  iconName: section.iconName,
                  defaultIcon: section.icon,
                  color: _kAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            section.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (highlighted) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _kAccent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Aktuelle Seite',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      section.summary,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Items
          for (int i = 0; i < section.items.length; i++) ...[
            _buildItemRow(section.items[i]),
            if (i < section.items.length - 1) const SizedBox(height: 12),
          ],

          // Hinweis
          if (section.note != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withOpacity(0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  getAdaptiveIcon(
                    iconName: 'info_outline',
                    defaultIcon: Icons.info_outline,
                    color: Colors.amber[800],
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      section.note!,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: Colors.brown[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Einzelnes Item ───────────────────────────────────────────────────
  Widget _buildItemRow(_HelpItem item) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: getAdaptiveIcon(
            iconName: item.iconName,
            defaultIcon: item.icon,
            color: _kAccent.withOpacity(0.85),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: Colors.grey[800],
              ),
              children: [
                TextSpan(
                  text: '${item.title}: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                TextSpan(text: item.text),
              ],
            ),
          ),
        ),
      ],
    );
  }
}