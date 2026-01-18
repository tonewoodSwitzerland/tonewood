import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/icon_helper.dart';
import 'customer_import_service_new.dart';


class CustomerImportDialog extends StatefulWidget {
  final VoidCallback onImportComplete;

  const CustomerImportDialog({
    Key? key,
    required this.onImportComplete,
  }) : super(key: key);

  @override
  State<CustomerImportDialog> createState() => _CustomerImportDialogState();
}

class _CustomerImportDialogState extends State<CustomerImportDialog> {
  List<CustomerImportData>? _importData;
  bool _isLoading = false;
  bool _isImporting = false;
  int _currentIndex = 0;
  double _importProgress = 0.0;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 800,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                getAdaptiveIcon(
                  iconName: 'upload_file',
                  defaultIcon: Icons.upload_file,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Kundenimport',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                  onPressed: _isImporting ? null : () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Content
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isImporting) {
      return _buildImportProgress();
    }

    if (_importData == null) {
      return _buildFileSelection();
    }

    return _buildPreview();
  }

  Widget _buildFileSelection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          getAdaptiveIcon(
            iconName: 'description',
            defaultIcon: Icons.description,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          const Text(
            'Excel-Datei auswählen',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Wählen Sie eine Excel-Datei (.xlsx) mit Kundendaten aus',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.error.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          FilledButton.icon(
            onPressed: _isLoading ? null : _pickFile,
            icon: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : getAdaptiveIcon(iconName: 'folder_open', defaultIcon: Icons.folder_open),
            label: Text(_isLoading ? 'Laden...' : 'Datei auswählen'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_importData == null || _importData!.isEmpty) {
      return const Center(child: Text('Keine Daten gefunden'));
    }

    final customer = _importData![_currentIndex];

    // Prüfe auf fehlende Pflichtfelder
    final hasWarnings = customer.strasseHausnummer.isEmpty ||
        customer.plzOrt.isEmpty ||
        customer.land.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              getAdaptiveIcon(
                iconName: 'info',
                defaultIcon: Icons.info,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_importData!.length} Kunden gefunden',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Prüfen Sie die Daten und bestätigen Sie den Import',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Warnung bei fehlenden Pflichtfeldern
        if (hasWarnings) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dieser Datensatz hat unvollständige Adressdaten',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Navigation
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: getAdaptiveIcon(iconName: 'arrow_back', defaultIcon: Icons.arrow_back),
              onPressed: _currentIndex > 0 ? _previousCustomer : null,
            ),
            Text(
              'Kunde ${_currentIndex + 1} von ${_importData!.length}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            IconButton(
              icon: getAdaptiveIcon(iconName: 'arrow_forward', defaultIcon: Icons.arrow_forward),
              onPressed: _currentIndex < _importData!.length - 1 ? _nextCustomer : null,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Customer Preview
        Expanded(
          child: SingleChildScrollView(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Basisdaten'),
                    _buildPreviewField('Firma', customer.firma),
                    _buildPreviewField('Name', customer.vornameName),
                    if (customer.email?.isNotEmpty ?? false)
                      _buildPreviewField('E-Mail', customer.email!),
                    if (customer.telefon1?.isNotEmpty ?? false)
                      _buildPreviewField('Telefon 1', customer.telefon1!),
                    if (customer.telefon2?.isNotEmpty ?? false)
                      _buildPreviewField('Telefon 2', customer.telefon2!),

                    const Divider(height: 32),

                    _buildSectionTitle('Adresse'),
                    _buildPreviewField('Straße & Hausnummer', customer.strasseHausnummer),
                    if (customer.zusatz?.isNotEmpty ?? false)
                      _buildPreviewField('Zusatz', customer.zusatz!),
                    if (customer.bezirkPostfach?.isNotEmpty ?? false)
                      _buildPreviewField('Bezirk/Postfach', customer.bezirkPostfach!),
                    _buildPreviewField('PLZ & Ort', customer.plzOrt),
                    _buildPreviewField('Land', '${customer.land}${customer.laenderkuerzel != null ? ' (${customer.laenderkuerzel})' : ''}'),

                    const Divider(height: 32),

                    _buildSectionTitle('Weitere Informationen'),
                    if (customer.vatNumber?.isNotEmpty ?? false)
                      _buildPreviewField('MwSt-Nummer', customer.vatNumber!),
                    if (customer.eoriNumber?.isNotEmpty ?? false)
                      _buildPreviewField('EORI-Nummer', customer.eoriNumber!),
                    if (customer.sprache?.isNotEmpty ?? false)
                      _buildPreviewField('Sprache', customer.sprache!),
                    if (customer.weihnachtskarte?.isNotEmpty ?? false)
                      _buildPreviewField('Weihnachtskarte', customer.weihnachtskarte!),
                    if (customer.notizen?.isNotEmpty ?? false)
                      _buildPreviewField('Notizen', customer.notizen!),

                    // Lieferadresse
                    if (customer.abweichendeLieferadresse?.toUpperCase() == 'JA' ||
                        customer.abweichendeLieferadresse?.toUpperCase() == 'YES') ...[
                      const Divider(height: 32),
                      _buildSectionTitle('Abweichende Lieferadresse'),
                      if (customer.lieferFirma?.isNotEmpty ?? false)
                        _buildPreviewField('Firma', customer.lieferFirma!),
                      if (customer.lieferVorname?.isNotEmpty ?? false)
                        _buildPreviewField('Vorname', customer.lieferVorname!),
                      if (customer.lieferNachname?.isNotEmpty ?? false)
                        _buildPreviewField('Nachname', customer.lieferNachname!),
                      if (customer.lieferStrasse?.isNotEmpty ?? false)
                        _buildPreviewField('Straße', customer.lieferStrasse!),
                      if (customer.lieferHausnummer?.isNotEmpty ?? false)
                        _buildPreviewField('Hausnummer', customer.lieferHausnummer!),
                      if ((customer.lieferPlz?.isNotEmpty ?? false) && (customer.lieferOrt?.isNotEmpty ?? false))
                        _buildPreviewField('PLZ & Ort', '${customer.lieferPlz} ${customer.lieferOrt}'),
                      if (customer.lieferLand?.isNotEmpty ?? false)
                        _buildPreviewField('Land', '${customer.lieferLand}${customer.lieferLaenderkuerzel != null ? ' (${customer.lieferLaenderkuerzel})' : ''}'),
                      if (customer.lieferTelefon?.isNotEmpty ?? false)
                        _buildPreviewField('Telefon', customer.lieferTelefon!),
                      if (customer.lieferEmail?.isNotEmpty ?? false)
                        _buildPreviewField('E-Mail', customer.lieferEmail!),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Action Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              onPressed: _cancelImport,
              icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
              label: const Text('Abbrechen'),
            ),
            FilledButton.icon(
              onPressed: _startImport,
              icon: getAdaptiveIcon(iconName: 'check', defaultIcon: Icons.check),
              label: Text('${_importData!.length} Kunden importieren'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildPreviewField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportProgress() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(strokeWidth: 6),
          ),
          const SizedBox(height: 32),
          Text(
            'Importiere Kunden...',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            '${(_importProgress * 100).toInt()}% abgeschlossen',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 400,
            height: 8,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _importProgress,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;

        final data = await CustomerImportService.parseExcelFile(filePath);

        if (data.isEmpty) {
          setState(() {
            _errorMessage = 'Keine gültigen Kundendaten in der Datei gefunden';
            _isLoading = false;
          });
          return;
        }

        setState(() {
          _importData = data;
          _currentIndex = 0;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Fehler beim Laden der Datei: $e';
        _isLoading = false;
      });
    }
  }

  void _previousCustomer() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  void _nextCustomer() {
    if (_currentIndex < _importData!.length - 1) {
      setState(() {
        _currentIndex++;
      });
    }
  }

  void _cancelImport() {
    Navigator.pop(context);
  }

  Future<void> _startImport() async {
    if (_importData == null || _importData!.isEmpty) return;

    setState(() {
      _isImporting = true;
      _importProgress = 0.0;
    });

    try {
      final result = await CustomerImportService.importCustomers(
        _importData!,
        onProgress: (current, total) {
          setState(() {
            _importProgress = current / total;
          });
        },
      );

      if (!mounted) return;

      Navigator.pop(context);

      // Zeige Erfolgs-/Fehler-Nachricht
      final successCount = result['success'] as int;
      final errorCount = result['errors'] as int;

      if (errorCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount Kunden erfolgreich importiert'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$successCount Kunden importiert, $errorCount Fehler',
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Details',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Import-Fehler'),
                    content: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final error in result['errorMessages'] as List<String>)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text('• $error'),
                            ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Schließen'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }

      widget.onImportComplete();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isImporting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Import: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}