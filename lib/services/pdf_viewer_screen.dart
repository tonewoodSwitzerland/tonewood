

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:share_plus/share_plus.dart';
import 'dart:io' if (dart.library.html) 'dart:html' as html;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'package:cross_file/cross_file.dart';


import 'dart:typed_data';
import '../services/download_helper_mobile.dart' if (dart.library.html) '../services/download_helper_web.dart';


import 'dart:io';

import 'package:http/http.dart' as http;

import 'dart:io' if (dart.library.html) 'dart:html' as html;

import 'icon_helper.dart';
class PDFViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String receiptId;

  const PDFViewerScreen({
    Key? key,
    required this.pdfUrl,
    required this.receiptId,
  }) : super(key: key);

  @override
  PDFViewerScreenState createState() => PDFViewerScreenState();
}

class PDFViewerScreenState extends State<PDFViewerScreen> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  final PdfViewerController _pdfViewerController = PdfViewerController();
  bool _isLoading = true;
  String? _errorMessage;

  Uint8List? _pdfBytes;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // PDF herunterladen
      final response = await http.get(Uri.parse(widget.pdfUrl));
      if (response.statusCode != 200) {
        throw 'HTTP Error: ${response.statusCode}';
      }

      _pdfBytes = response.bodyBytes;

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('PDF Load Error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Fehler beim Laden: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lieferschein'),
        actions: [
          IconButton(
            icon:getAdaptiveIcon(iconName: 'zoom_out', defaultIcon: Icons.zoom_out),
            onPressed: () {
              _pdfViewerController.zoomLevel = _pdfViewerController.zoomLevel + 0.25;
            },
          ),
          IconButton(
            icon:getAdaptiveIcon(iconName: 'zoom_in', defaultIcon: Icons.zoom_in),
            onPressed: () {
              _pdfViewerController.zoomLevel = _pdfViewerController.zoomLevel - 0.25;
            },
          ),
          IconButton(
            icon: getAdaptiveIcon(iconName: 'share', defaultIcon: Icons.share),
            onPressed: _pdfBytes != null ? () => _sharePdf(_pdfBytes!) : null,
          ),
          IconButton(
            icon:getAdaptiveIcon(iconName: 'download', defaultIcon: Icons.download),
            onPressed: _pdfBytes != null ? () => _downloadPdf(_pdfBytes!) : null,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPdf,
              child: const Text('Erneut versuchen'),
            ),
          ],
        ),
      );
    }

    if (_pdfBytes == null) {
      return const Center(
        child: Text('Keine PDF-Daten verfügbar'),
      );
    }

    return Container(
      color: Colors.grey[100],
      child: SfPdfViewer.memory(
        _pdfBytes!,
        key: _pdfViewerKey,
        controller: _pdfViewerController,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        enableDoubleTapZooming: true,
        enableTextSelection: true,
        pageLayoutMode: PdfPageLayoutMode.single,
        onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
          print('Fehler beim Laden: ${details.description}');
          setState(() {
            _errorMessage = 'Fehler beim Laden: ${details.description}';
          });
        },
        onDocumentLoaded: (PdfDocumentLoadedDetails details) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('PDF erfolgreich geladen'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 1),
              ),
            );
          }
        },
      ),
    );
  }
  @override


  Future<void> _sharePdf(Uint8List bytes) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/share_${widget.receiptId}.pdf');
      await tempFile.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        subject: 'Lieferschein Nr. ${widget.receiptId}',
      );

      if (await tempFile.exists()) {
        await tempFile.delete();
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
    }
  }

  Future<String> _saveReceiptLocally(Uint8List pdfBytes, String receiptId) async {
    String filePath="";
    try {
      final fileName = 'receipt_$receiptId.pdf';

      if (kIsWeb) {
        DownloadHelper.downloadFile(pdfBytes, fileName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF wird heruntergeladen...'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        filePath = await DownloadHelper.downloadFile(pdfBytes, fileName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gespeichert unter: $filePath'),
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
    }
    return filePath;
  }

  Future<void> _downloadPdf(Uint8List bytes) async {
    try {
      final path = await _saveReceiptLocally(bytes, widget.receiptId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF gespeichert: $path'),
            backgroundColor: Colors.green,
          ),
        );
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
    }
  }


  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }
}