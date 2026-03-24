// File: lib/services/pdf_header_footer_settings_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../icon_helper.dart';

// Nur für Mobile-PDF-Export
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Screen zum Anpassen der Kopf- und Fußzeilen-Inhalte in PDFs
class PdfHeaderFooterSettingsScreen extends StatefulWidget {
  const PdfHeaderFooterSettingsScreen({Key? key}) : super(key: key);

  @override
  State<PdfHeaderFooterSettingsScreen> createState() =>
      _PdfHeaderFooterSettingsScreenState();
}

class _PdfHeaderFooterSettingsScreenState
    extends State<PdfHeaderFooterSettingsScreen> {
  bool _isLoading = true;
  bool _isUploadingLogo = false;

  // ═══════════════════════════════════════════════════════════════════════════
  // LOGO
  // ═══════════════════════════════════════════════════════════════════════════
  String _logoSource = 'default';
  String? _customLogoUrl;
  Uint8List? _defaultLogoBytes;
  Uint8List? _customLogoPreviewBytes;

  // ═══════════════════════════════════════════════════════════════════════════
  // KOPFZEILE
  // ═══════════════════════════════════════════════════════════════════════════
  double _logoWidth = 180.0;
  double _compactLogoWidth = 100.0;
  double _titleFontSize = 28.0;
  double _headerLinesFontSize = 10.0;
  double _costCenterFontSize = 8.0;
  double _deliveryNoteTitleFontSize = 22.0;
  double _deliveryNoteLogoWidth = 140.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // FUSSZEILE
  // ═══════════════════════════════════════════════════════════════════════════
  double _footerFontSize = 8.0;
  double _footerPageNumberFontSize = 8.0;
  String _footerCompanyName = 'Florinett AG';
  String _footerCompanySubtitle = 'Tonewood Switzerland';
  String _footerStreet = 'Veja Zinols 6';
  String _footerZipCity = '7482 Bergün';
  String _footerCountry = 'Switzerland';
  String _footerPhone = 'phone: +41 81 407 21 34';
  String _footerEmail = 'e-mail: info@tonewood.ch';
  String _footerWebsite = 'website: www.tonewood.ch';
  String _footerVat = 'VAT: CHE-102.853.600 MWST';

  // Vorschau-Modus: welche Seite anzeigen
  int _previewPage = 0; // 0 = Standard-Header, 1 = Compact-Header

  @override
  void initState() {
    super.initState();
    _loadDefaultLogo();
    _loadSettings();
  }

  Future<void> _loadDefaultLogo() async {
    try {
      final data = await rootBundle.load('images/logo.png');
      if (mounted) setState(() => _defaultLogoBytes = data.buffer.asUint8List());
    } catch (e) {
      debugPrint('Fehler beim Laden des Standard-Logos: $e');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('general_data')
          .doc('pdf_header_footer_settings')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _logoSource = data['logo_source'] as String? ?? 'default';
          _customLogoUrl = data['custom_logo_url'] as String?;
          _logoWidth = (data['logo_width'] as num?)?.toDouble() ?? 180.0;
          _compactLogoWidth = (data['compact_logo_width'] as num?)?.toDouble() ?? 100.0;
          _titleFontSize = (data['title_font_size'] as num?)?.toDouble() ?? 28.0;
          _headerLinesFontSize = (data['header_lines_font_size'] as num?)?.toDouble() ?? 10.0;
          _costCenterFontSize = (data['cost_center_font_size'] as num?)?.toDouble() ?? 8.0;
          _deliveryNoteTitleFontSize = (data['delivery_note_title_font_size'] as num?)?.toDouble() ?? 22.0;
          _deliveryNoteLogoWidth = (data['delivery_note_logo_width'] as num?)?.toDouble() ?? 140.0;
          _footerFontSize = (data['footer_font_size'] as num?)?.toDouble() ?? 8.0;
          _footerPageNumberFontSize = (data['footer_page_number_font_size'] as num?)?.toDouble() ?? 8.0;
          _footerCompanyName = data['footer_company_name'] as String? ?? 'Florinett AG';
          _footerCompanySubtitle = data['footer_company_subtitle'] as String? ?? 'Tonewood Switzerland';
          _footerStreet = data['footer_street'] as String? ?? 'Veja Zinols 6';
          _footerZipCity = data['footer_zip_city'] as String? ?? '7482 Bergün';
          _footerCountry = data['footer_country'] as String? ?? 'Switzerland';
          _footerPhone = data['footer_phone'] as String? ?? 'phone: +41 81 407 21 34';
          _footerEmail = data['footer_email'] as String? ?? 'e-mail: info@tonewood.ch';
          _footerWebsite = data['footer_website'] as String? ?? 'website: www.tonewood.ch';
          _footerVat = data['footer_vat'] as String? ?? 'VAT: CHE-102.853.600 MWST';
        });

        if (_customLogoUrl != null && _customLogoUrl!.isNotEmpty) {
          _loadCustomLogoPreview();
        }
      }
    } catch (e) {
      debugPrint('Fehler beim Laden: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCustomLogoPreview() async {
    if (_customLogoUrl == null || _customLogoUrl!.isEmpty) return;
    try {
      final response = await http.get(Uri.parse(_customLogoUrl!));
      if (response.statusCode == 200 && mounted) {
        setState(() => _customLogoPreviewBytes = response.bodyBytes);
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Custom-Logo-Vorschau: $e');
    }
  }

  Future<void> _uploadCustomLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
        withData: true, // Wichtig für Web – liefert die Bytes direkt
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) return;

      setState(() => _isUploadingLogo = true);

      final ext = file.extension?.toLowerCase() ?? 'png';
      final fileName = 'pdf_custom_logo_${DateTime.now().millisecondsSinceEpoch}.$ext';

      final ref = FirebaseStorage.instance.ref('settings/logos/$fileName');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/$ext'));
      final downloadUrl = await ref.getDownloadURL();

      if (mounted) {
        setState(() {
          _customLogoUrl = downloadUrl;
          _customLogoPreviewBytes = bytes;
          _logoSource = 'custom';
          _isUploadingLogo = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo hochgeladen – vergiss nicht zu speichern!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingLogo = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteCustomLogo() async {
    if (_customLogoUrl == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logo löschen?'),
        content: const Text('Das benutzerdefinierte Logo wird entfernt.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      try { await FirebaseStorage.instance.refFromURL(_customLogoUrl!).delete(); } catch (_) {}
      setState(() { _customLogoUrl = null; _customLogoPreviewBytes = null; _logoSource = 'default'; });
    } catch (e) { debugPrint('Fehler: $e'); }
  }

  Future<void> _resetToDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.restart_alt, color: Colors.orange.shade700, size: 32),
        title: const Text('Auf Standard zurücksetzen?'),
        content: const Text(
          'Alle Einstellungen (Schriftgrößen, Logo-Breiten, Fußzeilen-Texte) '
              'werden auf die Standardwerte zurückgesetzt.\n\n'
              'Das benutzerdefinierte Logo bleibt erhalten, '
              'es wird aber wieder das Standard-Logo ausgewählt.\n\n'
              'Vergiss nicht, danach zu speichern!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Zurücksetzen'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      // Logo → Standard
      _logoSource = 'default';

      // Kopfzeile
      _logoWidth = 180.0;
      _compactLogoWidth = 100.0;
      _titleFontSize = 28.0;
      _headerLinesFontSize = 10.0;
      _costCenterFontSize = 8.0;
      _deliveryNoteTitleFontSize = 22.0;
      _deliveryNoteLogoWidth = 140.0;

      // Fußzeile
      _footerFontSize = 8.0;
      _footerPageNumberFontSize = 8.0;
      _footerCompanyName = 'Florinett AG';
      _footerCompanySubtitle = 'Tonewood Switzerland';
      _footerStreet = 'Veja Zinols 6';
      _footerZipCity = '7482 Bergün';
      _footerCountry = 'Switzerland';
      _footerPhone = 'phone: +41 81 407 21 34';
      _footerEmail = 'e-mail: info@tonewood.ch';
      _footerWebsite = 'website: www.tonewood.ch';
      _footerVat = 'VAT: CHE-102.853.600 MWST';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Standardwerte wiederhergestellt – jetzt speichern um zu übernehmen'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _saveSettings() async {
    try {
      await FirebaseFirestore.instance.collection('general_data').doc('pdf_header_footer_settings').set({
        'logo_source': _logoSource,
        'custom_logo_url': _customLogoUrl ?? '',
        'logo_width': _logoWidth,
        'compact_logo_width': _compactLogoWidth,
        'title_font_size': _titleFontSize,
        'header_lines_font_size': _headerLinesFontSize,
        'cost_center_font_size': _costCenterFontSize,
        'delivery_note_title_font_size': _deliveryNoteTitleFontSize,
        'delivery_note_logo_width': _deliveryNoteLogoWidth,
        'footer_font_size': _footerFontSize,
        'footer_page_number_font_size': _footerPageNumberFontSize,
        'footer_company_name': _footerCompanyName,
        'footer_company_subtitle': _footerCompanySubtitle,
        'footer_street': _footerStreet,
        'footer_zip_city': _footerZipCity,
        'footer_country': _footerCountry,
        'footer_phone': _footerPhone,
        'footer_email': _footerEmail,
        'footer_website': _footerWebsite,
        'footer_vat': _footerVat,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Einstellungen gespeichert'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red));
      }
    }
  }

  /// Aktives Logo (je nach Auswahl)
  Uint8List? get _activeLogo =>
      _logoSource == 'custom' && _customLogoPreviewBytes != null
          ? _customLogoPreviewBytes
          : _defaultLogoBytes;

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD — Responsive Layout
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kopf- & Fußzeile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kopf- & Fußzeile'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: OutlinedButton.icon(
              onPressed: _resetToDefaults,
              icon: getAdaptiveIcon(iconName: 'restart', defaultIcon: Icons.restart_alt, size: 18),
              label: const Text('Standard'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange.shade800,
                side: BorderSide(color: Colors.orange.shade300),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: _saveSettings,
              icon: getAdaptiveIcon(iconName: 'save', defaultIcon: Icons.save, size: 18),
              label: const Text('Speichern'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
      body: isWide ? _buildWideLayout(context) : _buildNarrowLayout(context),
    );
  }

  /// Desktop/Web: Split-View — Einstellungen links, Live-Vorschau rechts
  Widget _buildWideLayout(BuildContext context) {
    return Row(
      children: [
        // LINKE SEITE: Einstellungen (scrollbar)
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildSettingsPanel(context),
          ),
        ),

        // Trennlinie
        Container(width: 1, color: Colors.grey.shade300),

        // RECHTE SEITE: Live-Vorschau (fixiert)
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.grey.shade100,
            child: Column(
              children: [
                // Vorschau-Header mit Seitenwechsler
                _buildPreviewToolbar(context),
                // Vorschau
                Expanded(child: _buildLivePreview(context)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Mobile: Nur Einstellungen, kein Split
  Widget _buildNarrowLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSettingsPanel(context),
          const SizedBox(height: 16),
          // Inline-Vorschau für Mobile
          _buildSectionHeader(context, 'Vorschau', Icons.preview),
          const SizedBox(height: 12),
          _buildPreviewToolbar(context),
          const SizedBox(height: 8),
          SizedBox(
            height: 500,
            child: _buildLivePreview(context),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EINSTELLUNGEN PANEL
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSettingsPanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoBox(context),
        const SizedBox(height: 24),

        // LOGO
        _buildSectionHeader(context, 'Logo', Icons.image),
        const SizedBox(height: 16),
        _buildLogoSection(context),
        const SizedBox(height: 32),

        // KOPFZEILE
        _buildSectionHeader(context, 'Kopfzeile', Icons.vertical_align_top),
        const SizedBox(height: 16),
        _buildSubSectionTitle('Standard-Dokumente'),
        const SizedBox(height: 8),
        _buildSlider('Logo-Breite', 'Standard: 180 pt', _logoWidth, 80, 300, 180, (v) => setState(() => _logoWidth = v)),
        _buildSlider('Titel-Schriftgröße', 'z.B. "OFFERTE" (Standard: 28)', _titleFontSize, 14, 42, 28, (v) => setState(() => _titleFontSize = v)),
        _buildSlider('Info-Zeilen', 'Nr., Datum (Standard: 10)', _headerLinesFontSize, 6, 16, 10, (v) => setState(() => _headerLinesFontSize = v)),
        _buildSlider('Kostenstelle', 'Standard: 8', _costCenterFontSize, 6, 14, 8, (v) => setState(() => _costCenterFontSize = v)),
        const Divider(height: 24),
        _buildSubSectionTitle('Kompakt-Header (Folgeseiten)'),
        const SizedBox(height: 8),
        _buildSlider('Kompakt-Logo', 'Standard: 100 pt', _compactLogoWidth, 50, 200, 100, (v) => setState(() => _compactLogoWidth = v)),
        const Divider(height: 24),
        _buildSubSectionTitle('Lieferschein (Fenstertaschen)'),
        const SizedBox(height: 8),
        _buildSlider('LS Logo-Breite', 'Standard: 140 pt', _deliveryNoteLogoWidth, 80, 250, 140, (v) => setState(() => _deliveryNoteLogoWidth = v)),
        _buildSlider('LS Titel-Größe', 'Standard: 22', _deliveryNoteTitleFontSize, 12, 36, 22, (v) => setState(() => _deliveryNoteTitleFontSize = v)),
        const SizedBox(height: 32),

        // FUSSZEILE
        _buildSectionHeader(context, 'Fußzeile', Icons.vertical_align_bottom),
        const SizedBox(height: 16),
        _buildSlider('Schriftgröße', 'Standard: 8', _footerFontSize, 5, 14, 8, (v) => setState(() => _footerFontSize = v)),
        _buildSlider('Seitenzahl-Größe', 'Standard: 8', _footerPageNumberFontSize, 5, 14, 8, (v) => setState(() => _footerPageNumberFontSize = v)),
        const Divider(height: 24),
        _buildSubSectionTitle('Links – Firmenadresse'),
        const SizedBox(height: 8),
        _buildTextField('Firmenname (fett)', _footerCompanyName, (v) => setState(() => _footerCompanyName = v)),
        _buildTextField('Untertitel', _footerCompanySubtitle, (v) => setState(() => _footerCompanySubtitle = v)),
        _buildTextField('Straße', _footerStreet, (v) => setState(() => _footerStreet = v)),
        _buildTextField('PLZ & Ort', _footerZipCity, (v) => setState(() => _footerZipCity = v)),
        _buildTextField('Land', _footerCountry, (v) => setState(() => _footerCountry = v)),
        const Divider(height: 24),
        _buildSubSectionTitle('Rechts – Kontakt & UID'),
        const SizedBox(height: 8),
        _buildTextField('Telefon', _footerPhone, (v) => setState(() => _footerPhone = v)),
        _buildTextField('E-Mail', _footerEmail, (v) => setState(() => _footerEmail = v)),
        _buildTextField('Website', _footerWebsite, (v) => setState(() => _footerWebsite = v)),
        _buildTextField('UID / MWST', _footerVat, (v) => setState(() => _footerVat = v)),
        const SizedBox(height: 32),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LIVE-VORSCHAU (Flutter Widget, A4-Proportionen)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPreviewToolbar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          getAdaptiveIcon(iconName: 'preview', defaultIcon: Icons.preview, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text('Live-Vorschau', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Theme.of(context).colorScheme.primary)),
          const Spacer(),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Seite 1'), icon: Icon(Icons.looks_one, size: 16)),
              ButtonSegment(value: 1, label: Text('Folgeseite'), icon: Icon(Icons.looks_two, size: 16)),
            ],
            selected: {_previewPage},
            onSelectionChanged: (s) => setState(() => _previewPage = s.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreview(BuildContext context) {
    // A4 Proportionen: 210 x 297 mm → Verhältnis 1 : 1.4142
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AspectRatio(
          aspectRatio: 210 / 297,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4)),
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1)),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Skalierungsfaktor: Die Vorschau ist proportional zu echtem A4
                // Echter A4-Bereich: 210mm Breite, 20mm Rand = 170mm nutzbarer Bereich
                // Wir skalieren relativ zur verfügbaren Widget-Breite
                final scale = constraints.maxWidth / 595.0; // 595pt = A4-Breite

                return Padding(
                  padding: EdgeInsets.all(56 * scale), // ~20mm Rand
                  child: _previewPage == 0
                      ? _buildPage1Preview(scale)
                      : _buildPage2Preview(scale),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Seite 1: Voller Header + Fußzeile
  Widget _buildPage1Preview(double scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // HEADER
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Links: Titel + Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OFFERTE',
                    style: TextStyle(
                      fontSize: _titleFontSize * scale,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF546E7A),
                    ),
                  ),
                  SizedBox(height: 8 * scale),
                  _previewInfoRow('Nr.:', 'Q-2025-0001', _headerLinesFontSize * scale),
                  SizedBox(height: 2 * scale),
                  _previewInfoRow('Datum:', '20.02.2026', _headerLinesFontSize * scale),
                  SizedBox(height: 2 * scale),
                  _previewInfoRow('Kst-Nr.:', 'KST-001', _costCenterFontSize * scale),
                ],
              ),
            ),
            // Rechts: Logo
            if (_activeLogo != null)
              Image.memory(
                _activeLogo!,
                width: _logoWidth * scale,
                fit: BoxFit.contain,
              )
            else
              Container(
                width: _logoWidth * scale,
                height: 40 * scale,
                color: Colors.grey.shade200,
                child: Center(child: Icon(Icons.image, size: 20 * scale, color: Colors.grey)),
              ),
          ],
        ),

        SizedBox(height: 20 * scale),

        // Platzhalter Kundenadresse
        Container(
          padding: EdgeInsets.all(8 * scale),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300, width: 0.5),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _placeholderLine(scale, 0.4, bold: true),
              SizedBox(height: 3 * scale),
              _placeholderLine(scale, 0.35),
              SizedBox(height: 2 * scale),
              _placeholderLine(scale, 0.3),
              SizedBox(height: 2 * scale),
              _placeholderLine(scale, 0.25),
            ],
          ),
        ),

        SizedBox(height: 15 * scale),

        // Platzhalter Tabelle
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200, width: 0.5),
            ),
            child: Column(
              children: [
                // Header-Zeile
                Container(
                  height: 16 * scale,
                  color: const Color(0xFFECEFF1),
                ),
                ...List.generate(5, (i) => Container(
                  height: 12 * scale,
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 0.5)),
                  ),
                )),
              ],
            ),
          ),
        ),

        SizedBox(height: 8 * scale),

        // FOOTER
        _buildPreviewFooterWidget(scale, pageNumber: 1, totalPages: 2),
      ],
    );
  }

  /// Seite 2: Compact-Header + Fußzeile
  Widget _buildPage2Preview(double scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // COMPACT HEADER
        Container(
          padding: EdgeInsets.only(bottom: 6 * scale),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: const Color(0xFFCFD8DC), width: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'OFFERTE',
                    style: TextStyle(
                      fontSize: 14 * scale,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF546E7A),
                    ),
                  ),
                  SizedBox(width: 10 * scale),
                  Text(
                    'Q-2025-0001',
                    style: TextStyle(fontSize: 10 * scale, color: const Color(0xFF78909C)),
                  ),
                ],
              ),
              if (_activeLogo != null)
                Image.memory(_activeLogo!, width: _compactLogoWidth * scale, fit: BoxFit.contain)
              else
                Container(width: _compactLogoWidth * scale, height: 24 * scale, color: Colors.grey.shade200),
            ],
          ),
        ),

        SizedBox(height: 12 * scale),

        // Platzhalter Inhalt (Fortsetzung Tabelle)
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200, width: 0.5)),
            child: Column(
              children: List.generate(10, (i) => Container(
                height: 12 * scale,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 0.5)),
                ),
              )),
            ),
          ),
        ),

        SizedBox(height: 8 * scale),

        // FOOTER
        _buildPreviewFooterWidget(scale, pageNumber: 2, totalPages: 2),
      ],
    );
  }

  Widget _previewInfoRow(String label, String value, double fontSize) {
    return Row(
      children: [
        SizedBox(
          width: fontSize * 9,
          child: Text(label, style: TextStyle(fontSize: fontSize, color: const Color(0xFF78909C))),
        ),
        Text(value, style: TextStyle(fontSize: fontSize, color: const Color(0xFF78909C))),
      ],
    );
  }

  Widget _placeholderLine(double scale, double widthFraction, {bool bold = false}) {
    return FractionallySizedBox(
      widthFactor: widthFraction,
      child: Container(
        height: (bold ? 8 : 6) * scale,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildPreviewFooterWidget(double scale, {required int pageNumber, required int totalPages}) {
    final fs = _footerFontSize * scale;
    final pfs = _footerPageNumberFontSize * scale;

    return Container(
      padding: EdgeInsets.only(top: 6 * scale),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: const Color(0xFFCFD8DC), width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Links
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_footerCompanyName, style: TextStyle(fontSize: fs, fontWeight: FontWeight.bold, color: const Color(0xFF546E7A))),
              Text(_footerCompanySubtitle, style: TextStyle(fontSize: fs, color: const Color(0xFF78909C))),
              Text(_footerStreet, style: TextStyle(fontSize: fs, color: const Color(0xFF78909C))),
              Text(_footerZipCity, style: TextStyle(fontSize: fs, color: const Color(0xFF78909C))),
              Text(_footerCountry, style: TextStyle(fontSize: fs, color: const Color(0xFF78909C))),
            ],
          ),
          // Mitte: Seitenzahl
          Text('Seite $pageNumber / $totalPages', style: TextStyle(fontSize: pfs, color: const Color(0xFF90A4AE))),
          // Rechts
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_footerPhone, style: TextStyle(fontSize: fs, color: const Color(0xFF78909C))),
              Text(_footerEmail, style: TextStyle(fontSize: fs, color: const Color(0xFF78909C))),
              Text(_footerWebsite, style: TextStyle(fontSize: fs, color: const Color(0xFF78909C))),
              Text(_footerVat, style: TextStyle(fontSize: fs, color: const Color(0xFF78909C))),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOGO-SEKTION
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLogoSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildLogoOption(context,
                  title: 'Standard-Logo', subtitle: 'logo.png',
                  isSelected: _logoSource == 'default', imageBytes: _defaultLogoBytes,
                  onSelect: () => setState(() => _logoSource = 'default'),
                )),
                const SizedBox(width: 16),
                Expanded(child: _buildLogoOption(context,
                  title: 'Eigenes Logo',
                  subtitle: _customLogoUrl != null ? 'Hochgeladen' : 'Nicht vorhanden',
                  isSelected: _logoSource == 'custom', imageBytes: _customLogoPreviewBytes,
                  onSelect: _customLogoPreviewBytes != null ? () => setState(() => _logoSource = 'custom') : null,
                )),
              ],
            ),
            const SizedBox(height: 16),
            Row(children: [
              ElevatedButton.icon(
                onPressed: _isUploadingLogo ? null : _uploadCustomLogo,
                icon: _isUploadingLogo
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload, size: 18),
                label: Text(_customLogoUrl != null ? 'Ersetzen' : 'Hochladen'),
              ),
              if (_customLogoUrl != null) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _deleteCustomLogo,
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  label: const Text('Entfernen', style: TextStyle(color: Colors.red)),
                ),
              ],
            ]),
            const SizedBox(height: 10),
            Text('PNG mit transparentem Hintergrund empfohlen, max. 1200×600 px.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoOption(BuildContext context, {
    required String title, required String subtitle, required bool isSelected,
    Uint8List? imageBytes, VoidCallback? onSelect,
  }) {
    final canSelect = onSelect != null;
    return GestureDetector(
      onTap: canSelect ? onSelect : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.05) : Colors.grey.shade50,
        ),
        child: Column(children: [
          Row(children: [
            Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, size: 20,
                color: isSelected ? Theme.of(context).colorScheme.primary : (canSelect ? Colors.grey : Colors.grey.shade300)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: canSelect || isSelected ? null : Colors.grey)),
              Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ])),
          ]),
          const SizedBox(height: 12),
          Container(
            height: 50, width: double.infinity,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
            child: imageBytes != null
                ? Padding(padding: const EdgeInsets.all(6), child: Image.memory(imageBytes, fit: BoxFit.contain))
                : Center(child: Icon(Icons.image_not_supported, color: Colors.grey.shade300, size: 24)),
          ),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ALLGEMEINE WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildInfoBox(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
      ),
      child: Row(children: [
        getAdaptiveIcon(iconName: 'info', defaultIcon: Icons.info, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(
          'Logo, Kopf- und Fußzeilen aller PDF-Dokumente anpassen. Änderungen werden sofort in der Vorschau sichtbar.',
          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onPrimaryContainer),
        )),
      ]),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(8)),
        child: getAdaptiveIcon(iconName: title.toLowerCase().replaceAll(' ', '_'), defaultIcon: icon, color: Theme.of(context).colorScheme.primary),
      ),
      const SizedBox(width: 12),
      Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _buildSubSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.blueGrey.shade700)),
    );
  }

  Widget _buildSlider(String title, String subtitle, double value, double min, double max, double defaultValue, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Slider(value: value, min: min, max: max, divisions: (max - min).toInt(), onChanged: onChanged),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '${value.toStringAsFixed(0)}',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
            ),
          ),
          if (value != defaultValue)
            IconButton(
              icon: const Icon(Icons.refresh, size: 16),
              onPressed: () => onChanged(defaultValue),
              tooltip: 'Standard: ${defaultValue.toStringAsFixed(0)}',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            )
          else
            const SizedBox(width: 28),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String value, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label, isDense: true, border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        style: const TextStyle(fontSize: 13),
        onChanged: onChanged,
      ),
    );
  }
}

// ============================================================================
// Helper-Klasse zum Laden der Einstellungen (für Generatoren)
// ============================================================================

class PdfHeaderFooterSettings {
  final String logoSource;
  final String? customLogoUrl;
  final double logoWidth;
  final double compactLogoWidth;
  final double titleFontSize;
  final double headerLinesFontSize;
  final double costCenterFontSize;
  final double deliveryNoteTitleFontSize;
  final double deliveryNoteLogoWidth;
  final double footerFontSize;
  final double footerPageNumberFontSize;
  final String footerCompanyName;
  final String footerCompanySubtitle;
  final String footerStreet;
  final String footerZipCity;
  final String footerCountry;
  final String footerPhone;
  final String footerEmail;
  final String footerWebsite;
  final String footerVat;

  const PdfHeaderFooterSettings({
    this.logoSource = 'default',
    this.customLogoUrl,
    this.logoWidth = 180.0,
    this.compactLogoWidth = 100.0,
    this.titleFontSize = 28.0,
    this.headerLinesFontSize = 10.0,
    this.costCenterFontSize = 8.0,
    this.deliveryNoteTitleFontSize = 22.0,
    this.deliveryNoteLogoWidth = 140.0,
    this.footerFontSize = 8.0,
    this.footerPageNumberFontSize = 8.0,
    this.footerCompanyName = 'Florinett AG',
    this.footerCompanySubtitle = 'Tonewood Switzerland',
    this.footerStreet = 'Veja Zinols 6',
    this.footerZipCity = '7482 Bergün',
    this.footerCountry = 'Switzerland',
    this.footerPhone = 'phone: +41 81 407 21 34',
    this.footerEmail = 'e-mail: info@tonewood.ch',
    this.footerWebsite = 'website: www.tonewood.ch',
    this.footerVat = 'VAT: CHE-102.853.600 MWST',
  });

  bool get useCustomLogo => logoSource == 'custom' && customLogoUrl != null && customLogoUrl!.isNotEmpty;

  static Future<PdfHeaderFooterSettings> load() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('general_data')
          .doc('pdf_header_footer_settings')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        return PdfHeaderFooterSettings(
          logoSource: data['logo_source'] as String? ?? 'default',
          customLogoUrl: data['custom_logo_url'] as String?,
          logoWidth: (data['logo_width'] as num?)?.toDouble() ?? 180.0,
          compactLogoWidth: (data['compact_logo_width'] as num?)?.toDouble() ?? 100.0,
          titleFontSize: (data['title_font_size'] as num?)?.toDouble() ?? 28.0,
          headerLinesFontSize: (data['header_lines_font_size'] as num?)?.toDouble() ?? 10.0,
          costCenterFontSize: (data['cost_center_font_size'] as num?)?.toDouble() ?? 8.0,
          deliveryNoteTitleFontSize: (data['delivery_note_title_font_size'] as num?)?.toDouble() ?? 22.0,
          deliveryNoteLogoWidth: (data['delivery_note_logo_width'] as num?)?.toDouble() ?? 140.0,
          footerFontSize: (data['footer_font_size'] as num?)?.toDouble() ?? 8.0,
          footerPageNumberFontSize: (data['footer_page_number_font_size'] as num?)?.toDouble() ?? 8.0,
          footerCompanyName: data['footer_company_name'] as String? ?? 'Florinett AG',
          footerCompanySubtitle: data['footer_company_subtitle'] as String? ?? 'Tonewood Switzerland',
          footerStreet: data['footer_street'] as String? ?? 'Veja Zinols 6',
          footerZipCity: data['footer_zip_city'] as String? ?? '7482 Bergün',
          footerCountry: data['footer_country'] as String? ?? 'Switzerland',
          footerPhone: data['footer_phone'] as String? ?? 'phone: +41 81 407 21 34',
          footerEmail: data['footer_email'] as String? ?? 'e-mail: info@tonewood.ch',
          footerWebsite: data['footer_website'] as String? ?? 'website: www.tonewood.ch',
          footerVat: data['footer_vat'] as String? ?? 'VAT: CHE-102.853.600 MWST',
        );
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Kopf-/Fußzeilen-Einstellungen: $e');
    }
    return const PdfHeaderFooterSettings();
  }
}