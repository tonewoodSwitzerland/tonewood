import 'package:flutter/material.dart';
import '../services/icon_helper.dart';

/// Hilfe-Sheet/Dialog für Angebote und Aufträge.
/// Zeigt auf Web einen großen Dialog, auf Mobile ein Bottom Sheet.
///
/// Verwendung:
///   InfoHelpSheet.showForQuotes(context);
///   InfoHelpSheet.showForOrders(context);
class InfoHelpSheet {
  // ===== ANGEBOTE =====
  static void showForQuotes(BuildContext context) {
    _show(
      context,
      title: 'Angebote – Hilfe & Info',
      icon: Icons.description,
      iconName: 'description',
      sections: _quoteHelpSections,
      expertSections: _quoteExpertSections,
    );
  }

  // ===== AUFTRÄGE =====
  static void showForOrders(BuildContext context) {
    _show(
      context,
      title: 'Aufträge – Hilfe & Info',
      icon: Icons.assignment,
      iconName: 'assignment',
      sections: _orderHelpSections,
      expertSections: _orderExpertSections,
    );
  }

  // ===== INTERNER SHOW-MECHANISMUS =====
  static void _show(
      BuildContext context, {
        required String title,
        required IconData icon,
        required String iconName,
        required List<_HelpSection> sections,
        required List<_HelpSection> expertSections,
      }) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 750,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: _InfoHelpContent(
              title: title,
              icon: icon,
              iconName: iconName,
              sections: sections,
              expertSections: expertSections,
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: _InfoHelpContent(
            title: title,
            icon: icon,
            iconName: iconName,
            sections: sections,
            expertSections: expertSections,
          ),
        ),
      );
    }
  }

  // ===== ANGEBOTE HILFE-INHALTE =====
  static final List<_HelpSection> _quoteHelpSections = [
    _HelpSection(
      title: 'Übersicht',
      icon: Icons.dashboard,
      iconName: 'dashboard',
      content:
      'Die Angebotsübersicht zeigt alle erstellten Angebote auf einen Blick. '
          'Oben siehst du die Statistik-Karten mit der Anzahl offener und abgelaufener Angebote. '
          'Klicke auf eine Karte, um direkt nach diesem Status zu filtern.',
    ),
    _HelpSection(
      title: 'Angebotsstatus',
      icon: Icons.label,
      iconName: 'label',
      content:
      '• Offen (Blau): Das Angebot wurde erstellt und ist noch gültig. Es kann bearbeitet, beauftragen oder abgelehnt werden.\n\n'
          '• Angenommen (Grün): Das Angebot wurde in einen Auftrag umgewandelt. Es ist nicht mehr bearbeitbar.\n\n'
          '• Abgelehnt (Rot): Das Angebot wurde manuell abgelehnt. Reservierungen werden freigegeben.\n\n'
          '• Abgelaufen (Grau): Das Gültigkeitsdatum ist überschritten. Das Angebot kann weiterhin kopiert oder beauftragt werden.',
    ),
    _HelpSection(
      title: 'Filter & Suche',
      icon: Icons.filter_list,
      iconName: 'filter_list',
      content:
      'Nutze das Filter-Symbol in der App-Leiste, um nach Status und Datum zu filtern. '
          'Die Suchleiste durchsucht Angebotsnummer, Firmenname und Kundennamen. '
          'Drücke nach der Eingabe den Suchen-Button (oder Enter), um die Suche auszuführen.',
    ),
    _HelpSection(
      title: 'Aktionen',
      icon: Icons.touch_app,
      iconName: 'touch_app',
      content:
      '• Beauftragen: Wandelt das Angebot in einen Auftrag um. Lagerbestände werden gebucht und eine Rechnung wird erstellt.\n\n'
          '• Ablehnen: Markiert das Angebot als abgelehnt und gibt alle Reservierungen frei.\n\n'
          '• Löschen: Entfernt das Angebot vollständig inkl. Reservierungen, History und PDF.\n\n'
          '• Bearbeiten: Öffnet das Angebot im Verkaufsformular zur Änderung. Nur bei offenen Angeboten möglich.\n\n'
          '• Kopieren: Erstellt ein neues Angebot basierend auf den Daten des aktuellen Angebots.\n\n'
          '• PDF: Öffnet das generierte Angebots-PDF.\n\n'
          '• Teilen: Teilt die Angebotsinformationen per Share-Funktion.',
    ),
    _HelpSection(
      title: 'Gültigkeit & Ablauf',
      icon: Icons.timer,
      iconName: 'timer',
      content:
      'Jedes Angebot hat ein Gültigkeitsdatum (standardmäßig 14 Tage). '
          'Nach Ablauf wird das Angebot automatisch als "Abgelaufen" angezeigt. '
          'WICHTIG: Abgelaufene Angebote werden NICHT automatisch rückabgewickelt – '
          'Reservierungen bleiben bestehen, bis das Angebot manuell abgelehnt oder gelöscht wird. '
          'Es empfiehlt sich daher, abgelaufene Angebote regelmäßig zu prüfen und ggf. abzulehnen, '
          'um reservierte Lagerbestände wieder freizugeben.',
    ),
    _HelpSection(
      title: 'Reservierungen',
      icon: Icons.inventory_2,
      iconName: 'inventory_2',
      content:
      'Beim Erstellen eines Angebots werden die enthaltenen Produkte automatisch im Lager reserviert. '
          'Die Reservierung wird in folgenden Fällen aufgehoben:\n\n'
          '• Das Angebot wird abgelehnt\n'
          '• Das Angebot wird gelöscht\n'
          '• Das Angebot wird bearbeitet (alte Reservierungen werden gelöscht, neue erstellt)\n\n'
          'HINWEIS: Beim reinen Ablaufen eines Angebots werden Reservierungen NICHT automatisch freigegeben.',
    ),
  ];

  static final List<_HelpSection> _quoteExpertSections = [
    _HelpSection(
      title: 'Firestore-Struktur',
      icon: Icons.storage,
      iconName: 'storage',
      content:
      'Collection: quotes/{quoteId}\n\n'
          'Felder:\n'
          '• quoteNumber (String): Fortlaufende Nummer, Format YYYY-XXXX\n'
          '• status (String): draft, sent, accepted, rejected, expired\n'
          '• customer (Map): Kundendaten inkl. company, firstName, lastName, email\n'
          '• costCenter (Map?): Optionale Kostenstelle mit code und name\n'
          '• items (Array<Map>): Artikelliste mit product_id, quantity, price_per_unit etc.\n'
          '• calculations (Map): subtotal, net_amount, vat_amount, total, freight etc.\n'
          '• createdAt, validUntil (Timestamp)\n'
          '• documents.quote_pdf (String): URL des generierten PDFs\n'
          '• metadata (Map): currency, exchangeRates, taxOption, vatRate, shippingCosts etc.\n'
          '• isOrderCancelled (bool): Wird auf true gesetzt wenn der zugehörige Auftrag storniert wird\n\n'
          'Sub-Collection: quotes/{quoteId}/history\n'
          'Speichert alle Aktionen (Status-Änderungen, PDF-Ansichten, Teilen etc.)',
    ),
    _HelpSection(
      title: 'Reservierungs-Mechanismus',
      icon: Icons.lock,
      iconName: 'lock',
      content:
      'Collection: stock_movements\n\n'
          'Beim Erstellen eines Angebots:\n'
          '1. Für jedes Item wird ein stock_movement mit type=reservation, status=reserved erstellt\n'
          '2. quantity ist negativ (Abzug vom verfügbaren Bestand)\n'
          '3. Verknüpfung über quoteId\n\n'
          'Bei Ablehnung/Löschung:\n'
          '• status wird auf cancelled gesetzt\n'
          '• Der Bestand wird dadurch wieder als verfügbar angezeigt\n\n'
          'Bei Beauftragung:\n'
          '• Reservierungen werden zu bestätigten Bewegungen (confirmed)\n'
          '• Neuer stock_movement mit orderId wird erstellt\n\n'
          'Verfügbarkeitsberechnung:\n'
          'Verfügbar = inventory.quantity - SUM(reservierte Mengen)',
    ),
    _HelpSection(
      title: 'PDF-Generierung',
      icon: Icons.picture_as_pdf,
      iconName: 'picture_as_pdf',
      content:
      'PDFs werden serverseitig beim Erstellen/Bearbeiten generiert.\n\n'
          'Speicherort: Firebase Storage → documents/quotes/{quoteNumber}.pdf\n\n'
          'Das PDF berücksichtigt:\n'
          '• Währungsumrechnung (CHF, EUR, USD)\n'
          '• Schweizer Rundungsregeln (5-Rappen-Rundung für CHF)\n'
          '• Steueroptionen (MwSt, Reverse Charge, Steuerfrei)\n'
          '• Fracht- und Versandkosten\n'
          '• Zusatztexte und Dokumentensprache (DE, EN, FR, IT)',
    ),
    _HelpSection(
      title: 'Nummernvergabe',
      icon: Icons.tag,
      iconName: 'tag',
      content:
      'Angebotsnummern werden über einen Counter in general_data/quote_counters vergeben.\n\n'
          'Format: YYYY-XXXX (z.B. 2025-1001)\n\n'
          'Die Vergabe erfolgt transaktionsbasiert (runTransaction), '
          'um Race Conditions bei gleichzeitiger Erstellung zu vermeiden.\n\n'
          'Document-ID Format: Q-YYYY-XXXX',
    ),
  ];

  // ===== AUFTRÄGE HILFE-INHALTE =====
  static final List<_HelpSection> _orderHelpSections = [
    _HelpSection(
      title: 'Übersicht',
      icon: Icons.dashboard,
      iconName: 'dashboard',
      content:
      'Die Auftragsübersicht zeigt alle erstellten Aufträge. '
          'Die Statistik-Karten zeigen die Anzahl der Aufträge "In Bearbeitung" und "Versendet". '
          'Klicke auf eine Karte, um nach diesem Status zu filtern.',
    ),
    _HelpSection(
      title: 'Auftragsstatus',
      icon: Icons.label,
      iconName: 'label',
      content:
      '• In Bearbeitung (Blau): Der Auftrag ist aktiv und wird bearbeitet. Dokumente können erstellt werden.\n\n'
          '• Versendet (Lila): Der Auftrag wurde als versendet markiert. Alle Dokumente sollten erstellt sein.\n\n'
          '• Storniert (Grau): Der Auftrag wurde storniert. Produkte wurden zurück ins Lager gebucht.',
    ),
    _HelpSection(
      title: 'Filter & Suche',
      icon: Icons.filter_list,
      iconName: 'filter_list',
      content:
      'Nutze das Filter-Symbol für erweiterte Filteroptionen:\n\n'
          '• Auftragsstatus: Filtere nach einem oder mehreren Status\n'
          '• Auftragssumme: Filtere nach Mindest- und/oder Höchstbetrag\n'
          '• Veranlagungsverfügung: Filtere Aufträge über CHF 1\'000 nach Verfügungsstatus\n'
          '• Auftragsdatum: Aktuelles Jahr, aktueller Monat oder benutzerdefinierter Zeitraum\n\n'
          'Filter-Favoriten können gespeichert und jederzeit wieder geladen werden.',
    ),
    _HelpSection(
      title: 'Aktionen',
      icon: Icons.touch_app,
      iconName: 'touch_app',
      content:
      '• Status ändern: Ändere den Status zwischen "In Bearbeitung" und "Versendet".\n\n'
          '• Stornieren: Storniert den Auftrag und bucht alle Produkte zurück ins Lager. '
          'Online-Shop-Artikel werden wieder als verfügbar markiert.\n\n'
          '• Stornieren & Löschen: Wie Stornieren, aber der Auftrag wird zusätzlich komplett gelöscht.\n\n'
          '• Dokumente: Erstelle Rechnungen, Lieferscheine, Packlisten und Handelsrechnungen.\n\n'
          '• Teilen: Teilt die Auftragsinformationen per Share-Funktion.',
    ),
    _HelpSection(
      title: 'Dokumente',
      icon: Icons.folder_open,
      iconName: 'folder_open',
      content:
      'Für jeden Auftrag können folgende Dokumente erstellt werden:\n\n'
          '• Rechnung (Invoice): Die Hauptrechnung für den Kunden\n'
          '• Lieferschein (Delivery Note): Begleitdokument für die Lieferung\n'
          '• Packliste (Packing List): Detaillierte Auflistung der Pakete\n'
          '• Handelsrechnung (Commercial Invoice): Für den internationalen Versand\n\n'
          'Dokumente können jederzeit neu generiert, angezeigt, geteilt oder gelöscht werden.',
    ),
    _HelpSection(
      title: 'Veranlagungsverfügung',
      icon: Icons.assignment_turned_in,
      iconName: 'assignment_turned_in',
      content:
      'Bei Lieferungen über CHF 1\'000 ist eine Veranlagungsverfügung Ausfuhr erforderlich. '
          'Die Auftragsübersicht zeigt mit einem Badge an, ob die Verfügung fehlt. '
          'Die Veranlagungsnummer kann direkt im Auftragsdetail hinterlegt werden.',
    ),
  ];

  static final List<_HelpSection> _orderExpertSections = [
    _HelpSection(
      title: 'Firestore-Struktur',
      icon: Icons.storage,
      iconName: 'storage',
      content:
      'Collection: orders/{orderId}\n\n'
          'Felder:\n'
          '• orderNumber (String): Fortlaufende Nummer\n'
          '• quoteNumber (String?): Verknüpfte Angebotsnummer\n'
          '• quoteId (String?): Verknüpfte Angebots-ID\n'
          '• status (String): processing, shipped, cancelled\n'
          '• customer (Map): Kundendaten\n'
          '• costCenter (Map?): Kostenstelle\n'
          '• items (Array<Map>): Artikelliste mit Mengen, Preisen, Maßen\n'
          '• calculations (Map): Berechnungen inkl. subtotal, net_amount, vat_amount, total\n'
          '• orderDate, deliveryDate (Timestamp)\n'
          '• documents (Map<String, String>): URLs aller generierten PDFs\n'
          '• metadata (Map): currency, exchangeRates, invoiceSettings, veranlagungsnummer etc.\n\n'
          'Sub-Collections:\n'
          '• orders/{orderId}/history – Alle Aktionen\n'
          '• orders/{orderId}/packing_list/settings – Packlisten-Konfiguration',
    ),
    _HelpSection(
      title: 'Bestandsbuchungen',
      icon: Icons.swap_vert,
      iconName: 'swap_vert',
      content:
      'Collection: stock_movements\n\n'
          'Beim Beauftragen eines Angebots:\n'
          '1. Reservierungen (quoteId) werden storniert\n'
          '2. Neue Bewegungen mit orderId, type=sale, status=confirmed werden erstellt\n'
          '3. inventory.quantity wird decrementiert\n\n'
          'Bei Stornierung:\n'
          '1. stock_movements mit orderId+status=confirmed werden auf cancelled gesetzt\n'
          '2. inventory.quantity wird um die Menge incrementiert\n'
          '3. Online-Shop Items: sold=false, in_cart=false\n'
          '4. Wenn quoteId vorhanden: Quote bekommt isOrderCancelled=true',
    ),
    _HelpSection(
      title: 'Status-Migration',
      icon: Icons.sync,
      iconName: 'sync',
      content:
      'Das System hat eine Status-Migration von 5 auf 3 Status:\n\n'
          '• pending → processing\n'
          '• processing → processing\n'
          '• shipped → shipped\n'
          '• delivered → shipped\n'
          '• cancelled → cancelled\n\n'
          'Die Migration erfolgt automatisch beim Laden über OrderX.fromFirestore().',
    ),
    _HelpSection(
      title: 'Filter-Persistenz',
      icon: Icons.save,
      iconName: 'save',
      content:
      'Auftragsfilter werden in general_data/order_filter_settings gespeichert.\n\n'
          'Filter-Favoriten: general_data/order_filter_settings/order_filter_favorites\n\n'
          'Angebotsfilter werden in general_data/quote_filter_settings gespeichert.\n\n'
          'Alle Filter werden als Stream geladen, sodass Änderungen in Echtzeit '
          'zwischen allen offenen Sitzungen synchronisiert werden.',
    ),
  ];
}

// ===== HILFE-SEKTION MODEL =====
class _HelpSection {
  final String title;
  final IconData icon;
  final String iconName;
  final String content;

  const _HelpSection({
    required this.title,
    required this.icon,
    required this.iconName,
    required this.content,
  });
}

// ===== CONTENT WIDGET =====
class _InfoHelpContent extends StatefulWidget {
  final String title;
  final IconData icon;
  final String iconName;
  final List<_HelpSection> sections;
  final List<_HelpSection> expertSections;

  const _InfoHelpContent({
    required this.title,
    required this.icon,
    required this.iconName,
    required this.sections,
    required this.expertSections,
  });

  @override
  State<_InfoHelpContent> createState() => _InfoHelpContentState();
}

class _InfoHelpContentState extends State<_InfoHelpContent> {
  bool _expertMode = false;

  @override
  Widget build(BuildContext context) {
    final activeSections = _expertMode
        ? [...widget.sections, ...widget.expertSections]
        : widget.sections;

    return Column(
      children: [
        // Drag Handle (nur mobile)
        if (MediaQuery.of(context).size.width <= 800)
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
            border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5))),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  getAdaptiveIcon(
                    iconName: widget.iconName,
                    defaultIcon: widget.icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Experten-Modus Toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _expertMode
                      ? Colors.deepPurple.withOpacity(0.1)
                      : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _expertMode ? Colors.deepPurple.withOpacity(0.3) : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    getAdaptiveIcon(
                      iconName: 'code',
                      defaultIcon: Icons.code,
                      size: 18,
                      color: _expertMode ? Colors.deepPurple : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Experten-Modus',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _expertMode ? FontWeight.w600 : FontWeight.normal,
                        color: _expertMode ? Colors.deepPurple : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _expertMode,
                      onChanged: (value) {
                        setState(() {
                          _expertMode = value;
                        });
                      },
                      activeColor: Colors.deepPurple,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: activeSections.length,
            itemBuilder: (context, index) {
              final section = activeSections[index];
              final isExpertSection = index >= widget.sections.length;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isExpertSection
                      ? Colors.deepPurple.withOpacity(0.05)
                      : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: isExpertSection
                      ? Border.all(color: Colors.deepPurple.withOpacity(0.2))
                      : null,
                ),
                child: ExpansionTile(
                  initiallyExpanded: index == 0 && !isExpertSection,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (isExpertSection ? Colors.deepPurple : Theme.of(context).colorScheme.primary).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: getAdaptiveIcon(
                        iconName: section.iconName,
                        defaultIcon: section.icon,
                        size: 20,
                        color: isExpertSection ? Colors.deepPurple : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          section.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: isExpertSection ? Colors.deepPurple : null,
                          ),
                        ),
                      ),
                      if (isExpertSection)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'EXPERTE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          section.content,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                            fontFamily: isExpertSection ? 'monospace' : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}