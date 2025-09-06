
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/icon_helper.dart';

// Einfache, elegante Scanner-Implementierung
class SimpleBarcodeScannerPage extends StatefulWidget {
  @override
  _SimpleBarcodeScannerPageState createState() => _SimpleBarcodeScannerPageState();
}

class _SimpleBarcodeScannerPageState extends State<SimpleBarcodeScannerPage> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );
  bool hasScanned = false;

  @override
  Widget build(BuildContext context) {
    final scanWidth = 350.0;  // Breite für rechteckigen Scan-Bereich
    final scanHeight = 200.0; // Höhe für rechteckigen Scan-Bereich

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Kamera
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (!hasScanned && capture.barcodes.isNotEmpty) {
                final String? code = capture.barcodes.first.rawValue;
                if (code != null) {
                  hasScanned = true;
                  HapticFeedback.mediumImpact();
                  Navigator.pop(context, code);
                }
              }
            },
          ),

          // Overlay mit Scan-Bereich
          Container(
            decoration: ShapeDecoration(
              shape: _ScannerOverlayShape(
                borderColor: Colors.white,
                borderWidth: 3,
                overlayColor: Colors.black.withOpacity(0.5),
                borderRadius: 12,
                borderLength: 30,
                scanWidth: scanWidth,
                scanHeight: scanHeight,
              ),
            ),
          ),

          // Header
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 40),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Barcode scannen',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),

          // Close Button
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon:  getAdaptiveIcon(iconName: 'close', defaultIcon:Icons.close, color: Colors.white, size: 30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

// Custom ShapeBorder für den Scanner Overlay
class _ScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double scanWidth;
  final double scanHeight;

  const _ScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 3.0,
    this.overlayColor = const Color(0x88000000),
    this.borderRadius = 12,
    this.borderLength = 30,
    this.scanWidth = 300,
    this.scanHeight = 200,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(0);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..addRect(Rect.fromLTWH(
        rect.center.dx - scanWidth / 2,
        rect.center.dy - scanHeight / 2,
        scanWidth,
        scanHeight,
      ));
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRect(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final double left = rect.center.dx - scanWidth / 2;
    final double top = rect.center.dy - scanHeight / 2;
    final double right = left + scanWidth;
    final double bottom = top + scanHeight;

    // Dunkler Hintergrund
    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final backgroundPath = Path()
      ..addRect(rect)
      ..addRRect(RRect.fromLTRBR(
          left, top, right, bottom,
          Radius.circular(borderRadius)
      ))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(backgroundPath, backgroundPaint);

    // Weißer Rahmen
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final borderRect = RRect.fromLTRBR(
      left, top, right, bottom,
      Radius.circular(borderRadius),
    );

    canvas.drawRRect(borderRect, borderPaint);

    // Ecken betonen
    final cornerPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth * 1.5
      ..strokeCap = StrokeCap.round;

    // Oben links
    canvas.drawLine(
      Offset(left - 1, top + borderLength),
      Offset(left - 1, top + borderRadius),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + borderRadius, top - 1),
      Offset(left + borderLength, top - 1),
      cornerPaint,
    );

    // Oben rechts
    canvas.drawLine(
      Offset(right + 1, top + borderLength),
      Offset(right + 1, top + borderRadius),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(right - borderRadius, top - 1),
      Offset(right - borderLength, top - 1),
      cornerPaint,
    );

    // Unten links
    canvas.drawLine(
      Offset(left - 1, bottom - borderLength),
      Offset(left - 1, bottom - borderRadius),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + borderRadius, bottom + 1),
      Offset(left + borderLength, bottom + 1),
      cornerPaint,
    );

    // Unten rechts
    canvas.drawLine(
      Offset(right + 1, bottom - borderLength),
      Offset(right + 1, bottom - borderRadius),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(right - borderRadius, bottom + 1),
      Offset(right - borderLength, bottom + 1),
      cornerPaint,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return _ScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth * t,
      overlayColor: overlayColor,
      borderRadius: borderRadius * t,
      borderLength: borderLength * t,
      scanWidth: scanWidth * t,
      scanHeight: scanHeight * t,
    );
  }
}

