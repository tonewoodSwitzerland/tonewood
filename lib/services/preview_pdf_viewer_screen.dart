// File: services/preview_pdf_viewer_screen.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:typed_data';
import 'download_helper_mobile.dart' if (dart.library.html) 'download_helper_web.dart';
import 'icon_helper.dart';

class PreviewPDFViewerScreen extends StatefulWidget {
  final Uint8List pdfBytes;
  final String title;

  const PreviewPDFViewerScreen({
    Key? key,
    required this.pdfBytes,
    required this.title,
  }) : super(key: key);

  @override
  PreviewPDFViewerScreenState createState() => PreviewPDFViewerScreenState();
}

class PreviewPDFViewerScreenState extends State<PreviewPDFViewerScreen> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  final PdfViewerController _pdfViewerController = PdfViewerController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'PREVIEW',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),

          ],
        ),
        actions: [
          // Zoom Out
          IconButton(
            icon: getAdaptiveIcon(iconName: 'zoom_out', defaultIcon: Icons.zoom_out),
            onPressed: () {
              final currentZoom = _pdfViewerController.zoomLevel;
              _pdfViewerController.zoomLevel = (currentZoom - 0.25).clamp(0.5, 3.0);
            },
            tooltip: 'Verkleinern',
          ),

          // Zoom In
          IconButton(
            icon: getAdaptiveIcon(iconName: 'zoom_in', defaultIcon: Icons.zoom_in),
            onPressed: () {
              final currentZoom = _pdfViewerController.zoomLevel;
              _pdfViewerController.zoomLevel = (currentZoom + 0.25).clamp(0.5, 3.0);
            },
            tooltip: 'Vergrößern',
          ),

          // Share
          IconButton(
            icon: getAdaptiveIcon(iconName: 'share', defaultIcon: Icons.share),
            onPressed: _isLoading ? null : _sharePdf,
            tooltip: 'Teilen',
          ),

          // Download
          IconButton(
            icon: getAdaptiveIcon(iconName: 'download', defaultIcon: Icons.download),
            onPressed: _isLoading ? null : _downloadPdf,
            tooltip: 'Herunterladen',
          ),

          // Mehr Optionen
          PopupMenuButton<String>(
            icon: getAdaptiveIcon(iconName: 'more_vert', defaultIcon: Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'fit_width':
                  _pdfViewerController.zoomLevel = 1.0;
                  break;
                case 'fit_page':
                  _pdfViewerController.zoomLevel = 0.8;
                  break;
                case 'info':
                  _showDocumentInfo();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'fit_width',
                child: Row(
                  children: [
                    getAdaptiveIcon(iconName: 'fit_screen', defaultIcon: Icons.fit_screen),
                    const SizedBox(width: 8),
                    const Text('An Breite anpassen'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'fit_page',
                child: Row(
                  children: [
                    getAdaptiveIcon(iconName: 'fullscreen', defaultIcon: Icons.fullscreen),
                    const SizedBox(width: 8),
                    const Text('Ganze Seite'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    getAdaptiveIcon(iconName: 'info', defaultIcon: Icons.info),
                    const SizedBox(width: 8),
                    const Text('Dokumentinfo'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      body: Container(
        color: Colors.grey[100],
        child: Stack(
          children: [
            SfPdfViewer.memory(
              widget.pdfBytes,
              key: _pdfViewerKey,
              controller: _pdfViewerController,
              canShowScrollHead: true,
              canShowScrollStatus: true,
              enableDoubleTapZooming: true,
              enableTextSelection: true,
              pageLayoutMode: PdfPageLayoutMode.single,
              onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                print('PDF Load Failed: ${details.description}');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Fehler beim Laden: ${details.description}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('PDF geladen - ${details.document.pages.count} Seiten'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),

            // Preview-Wasserzeichen
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    getAdaptiveIcon(
                      iconName: 'visibility',
                      defaultIcon: Icons.visibility,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'VORSCHAU',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Loading Overlay
            if (_isLoading)
              Container(
                color: Colors.black26,
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Verarbeitung läuft...'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),


    );
  }

  Future<void> _sharePdf() async {
    setState(() => _isLoading = true);

    try {
      if (kIsWeb) {
        await DownloadHelper.downloadFile(widget.pdfBytes, widget.title);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF wird heruntergeladen...'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/${widget.title}');
        await tempFile.writeAsBytes(widget.pdfBytes);

        await Share.shareXFiles(
          [XFile(tempFile.path)],
          subject: 'Dokument: ${widget.title}',
        );

        // Cleanup
        Future.delayed(const Duration(minutes: 5), () async {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Teilen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _downloadPdf() async {
    setState(() => _isLoading = true);

    try {
      if (kIsWeb) {
        await DownloadHelper.downloadFile(widget.pdfBytes, widget.title);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF wird heruntergeladen...'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final downloadPath = await DownloadHelper.downloadFile(widget.pdfBytes, widget.title);
        if (mounted && downloadPath != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gespeichert: $downloadPath'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showDocumentInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            getAdaptiveIcon(iconName: 'info', defaultIcon: Icons.info),
            const SizedBox(width: 8),
            const Text('Dokumentinfo'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Dateiname:', widget.title),
            _buildInfoRow('Größe:', '${(widget.pdfBytes.length / 1024).toStringAsFixed(1)} KB'),
            _buildInfoRow('Typ:', 'PDF-Dokument'),
            _buildInfoRow('Status:', 'Vorschau (nicht gespeichert)'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  getAdaptiveIcon(
                    iconName: 'warning',
                    defaultIcon: Icons.warning,
                    color: Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Dies ist eine Vorschau. Das Dokument wurde noch nicht in der Datenbank gespeichert.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }
}