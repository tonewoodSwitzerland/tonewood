// ═══════════════════════════════════════════════════════════════════════════
// lib/widgets/dialogs/barcode_input_dialog.dart
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/icon_helper.dart';

/// Barcode-Typ für unterschiedliche Formate
enum BarcodeInputType {
  /// Produktions-Barcode: IIPP.HHQQ.ThHaMoFs.JJ (4.4.4.2 = 14 Ziffern)
  production,
  /// Verkaufs-Barcode: IIPP.HHQQ (4.4 = 8 Ziffern)
  sales,
}

class _BarcodeSegment {
  final String label;
  final int length;
  const _BarcodeSegment({required this.label, required this.length});
}

/// Zeigt einen Barcode-Input-Dialog (Desktop) oder Bottom Sheet (Mobile)
Future<String?> showBarcodeInputDialog({
  required BuildContext context,
  BarcodeInputType type = BarcodeInputType.production,
  String? initialValue,
}) {
  final screenWidth = MediaQuery.of(context).size.width;
  final isMobile = screenWidth < 600;

  if (isMobile) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BarcodeInputContent(
        type: type,
        initialValue: initialValue,
        isMobile: true,
      ),
    );
  } else {
    return showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: _BarcodeInputContent(
          type: type,
          initialValue: initialValue,
          isMobile: false,
        ),
      ),
    );
  }
}

class _BarcodeInputContent extends StatefulWidget {
  final BarcodeInputType type;
  final String? initialValue;
  final bool isMobile;

  const _BarcodeInputContent({
    required this.type,
    this.initialValue,
    required this.isMobile,
  });

  @override
  State<_BarcodeInputContent> createState() => _BarcodeInputContentState();
}

class _BarcodeInputContentState extends State<_BarcodeInputContent> {
  late List<_BarcodeSegment> segments;
  late List<String> segmentValues;
  int currentSegmentIndex = 0;

  static const Color primaryColor = Color(0xFF0F4A29);
  static const Color errorColor = Color(0xFFD32F2F);
  static const Color successColor = Color(0xFF388E3C);

  @override
  void initState() {
    super.initState();
    _initializeSegments();
    _parseInitialValue();
  }

  void _initializeSegments() {
    if (widget.type == BarcodeInputType.production) {
      segments = const [
        _BarcodeSegment(label: 'IIPP', length: 4),
        _BarcodeSegment(label: 'HHQQ', length: 4),
        _BarcodeSegment(label: 'ThHaMoFs', length: 4),
        _BarcodeSegment(label: 'JJ', length: 2),
      ];
    } else {
      segments = const [
        _BarcodeSegment(label: 'IIPP', length: 4),
        _BarcodeSegment(label: 'HHQQ', length: 4),
      ];
    }
    segmentValues = List.filled(segments.length, '');
  }

  void _parseInitialValue() {
    if (widget.initialValue != null && widget.initialValue!.isNotEmpty) {
      final parts = widget.initialValue!.split('.');
      for (int i = 0; i < parts.length && i < segments.length; i++) {
        segmentValues[i] = parts[i];
      }
      for (int i = 0; i < segments.length; i++) {
        if (segmentValues[i].length < segments[i].length) {
          currentSegmentIndex = i;
          break;
        }
      }
    }
  }

  String get fullBarcode => segmentValues.join('.');

  bool get isComplete {
    for (int i = 0; i < segments.length; i++) {
      if (segmentValues[i].length != segments[i].length) return false;
    }
    return true;
  }

  int get totalDigits => segmentValues.fold(0, (sum, s) => sum + s.length);
  int get requiredDigits => segments.fold(0, (sum, s) => sum + s.length);

  void _handleDigit(String digit) {
    setState(() {
      final segment = segments[currentSegmentIndex];
      final value = segmentValues[currentSegmentIndex];

      if (value.length < segment.length) {
        segmentValues[currentSegmentIndex] = value + digit;

        if (segmentValues[currentSegmentIndex].length == segment.length) {
          if (currentSegmentIndex < segments.length - 1) {
            currentSegmentIndex++;
          }
        }
      }
    });
  }

  void _handleBackspace() {
    setState(() {
      final value = segmentValues[currentSegmentIndex];

      if (value.isNotEmpty) {
        segmentValues[currentSegmentIndex] = value.substring(0, value.length - 1);
      } else if (currentSegmentIndex > 0) {
        currentSegmentIndex--;
        final prev = segmentValues[currentSegmentIndex];
        if (prev.isNotEmpty) {
          segmentValues[currentSegmentIndex] = prev.substring(0, prev.length - 1);
        }
      }
    });
  }

  void _handleClear() {
    setState(() {
      segmentValues = List.filled(segments.length, '');
      currentSegmentIndex = 0;
    });
  }

  void _handleSegmentTap(int index) {
    setState(() => currentSegmentIndex = index);
  }

  void _handleConfirm() {
    if (isComplete) Navigator.pop(context, fullBarcode);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isMobile) {
      return _buildMobileLayout();
    } else {
      return _buildDesktopLayout();
    }
  }

  Widget _buildMobileLayout() {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildBarcodeDisplayMobile(),
                  const SizedBox(height: 8),
                  _buildProgressIndicator(),
                  const SizedBox(height: 16),
                  _buildNumpadMobile(),
                  const SizedBox(height: 12),
                  _buildActionButtons(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Container(
      width: 450,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildBarcodeDisplayDesktop(),
          const SizedBox(height: 12),
          _buildProgressIndicator(),
          const SizedBox(height: 24),
          _buildNumpadDesktop(),
          const SizedBox(height: 20),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final title = widget.type == BarcodeInputType.production
        ? 'Produktions-Barcode'
        : 'Verkaufs-Barcode';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: getAdaptiveIcon(
            iconName: 'qr_code',
            defaultIcon: Icons.qr_code,
            color: primaryColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              Text(
                'Tippe die Ziffern ein',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: getAdaptiveIcon(
            iconName: 'close',
            defaultIcon: Icons.close,
            color: Colors.grey[400],
          ),
          splashRadius: 20,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // MOBILE: Kompakte vertikale Darstellung
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildBarcodeDisplayMobile() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          // Barcode als Text-Vorschau
          Text(
            fullBarcode.isEmpty ? segments.map((s) => '─' * s.length).join('.') : fullBarcode,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              letterSpacing: 2,
              color: isComplete ? successColor : primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          // Segment-Buttons in einer Zeile
          Row(
            children: List.generate(segments.length, (index) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 0 : 4,
                    right: index == segments.length - 1 ? 0 : 4,
                  ),
                  child: _buildSegmentChipMobile(index),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentChipMobile(int index) {
    final segment = segments[index];
    final value = segmentValues[index];
    final isActive = index == currentSegmentIndex;
    final isFilled = value.length == segment.length;

    return GestureDetector(
      onTap: () => _handleSegmentTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isActive
              ? primaryColor.withOpacity(0.15)
              : isFilled
              ? successColor.withOpacity(0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? primaryColor
                : isFilled
                ? successColor
                : Colors.grey[300]!,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              value.isEmpty ? '----'.substring(0, segment.length) : value.padRight(segment.length, '-'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: isFilled ? successColor : primaryColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              segment.label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: isActive ? primaryColor : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpadMobile() {
    const double buttonSize = 64;
    const double fontSize = 24;

    return Column(
      children: [
        _buildNumpadRow(['1', '2', '3'], buttonSize, fontSize),
        const SizedBox(height: 8),
        _buildNumpadRow(['4', '5', '6'], buttonSize, fontSize),
        const SizedBox(height: 8),
        _buildNumpadRow(['7', '8', '9'], buttonSize, fontSize),
        const SizedBox(height: 8),
        _buildNumpadRow(['C', '0', '⌫'], buttonSize, fontSize),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // DESKTOP: Ausführliche horizontale Darstellung
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildBarcodeDisplayDesktop() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(segments.length * 2 - 1, (index) {
          if (index.isOdd) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '.',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            );
          }
          return _buildSegmentBoxDesktop(index ~/ 2);
        }),
      ),
    );
  }

  Widget _buildSegmentBoxDesktop(int index) {
    final segment = segments[index];
    final value = segmentValues[index];
    final isActive = index == currentSegmentIndex;
    final isFilled = value.length == segment.length;

    return GestureDetector(
      onTap: () => _handleSegmentTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isActive
              ? primaryColor.withOpacity(0.1)
              : isFilled
              ? successColor.withOpacity(0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? primaryColor
                : isFilled
                ? successColor.withOpacity(0.3)
                : Colors.transparent,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(segment.length, (digitIndex) {
                final hasDigit = digitIndex < value.length;
                final isNext = digitIndex == value.length && isActive;

                return Container(
                  width: 24,
                  height: 34,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: hasDigit ? primaryColor.withOpacity(0.1) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isNext
                          ? primaryColor
                          : hasDigit
                          ? primaryColor.withOpacity(0.3)
                          : Colors.grey[300]!,
                      width: isNext ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: hasDigit
                        ? Text(
                      value[digitIndex],
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    )
                        : isNext
                        ? Container(width: 2, height: 18, color: primaryColor)
                        : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: 4),
            Text(
              segment.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isActive ? primaryColor : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpadDesktop() {
    const double buttonSize = 72;
    const double fontSize = 28;

    return Column(
      children: [
        _buildNumpadRow(['1', '2', '3'], buttonSize, fontSize),
        const SizedBox(height: 10),
        _buildNumpadRow(['4', '5', '6'], buttonSize, fontSize),
        const SizedBox(height: 10),
        _buildNumpadRow(['7', '8', '9'], buttonSize, fontSize),
        const SizedBox(height: 10),
        _buildNumpadRow(['C', '0', '⌫'], buttonSize, fontSize),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SHARED COMPONENTS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        LinearProgressIndicator(
          value: totalDigits / requiredDigits,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(
            isComplete ? successColor : primaryColor,
          ),
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
        ),
        const SizedBox(height: 4),
        Text(
          '$totalDigits / $requiredDigits Ziffern',
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildNumpadRow(List<String> labels, double buttonSize, double fontSize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: labels.map((label) => _buildNumpadButton(label, buttonSize, fontSize)).toList(),
    );
  }

  Widget _buildNumpadButton(String label, double size, double fontSize) {
    Color bgColor;
    Color textColor;
    VoidCallback? onTap;

    switch (label) {
      case 'C':
        bgColor = errorColor.withOpacity(0.1);
        textColor = errorColor;
        onTap = _handleClear;
        break;
      case '⌫':
        bgColor = Colors.grey[100]!;
        textColor = Colors.grey[700]!;
        onTap = _handleBackspace;
        break;
      default:
        bgColor = Colors.grey[50]!;
        textColor = primaryColor;
        onTap = isComplete ? null : () => _handleDigit(label);
    }

    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: label == '⌫'
                ? getAdaptiveIcon(
              iconName: 'backspace',
              defaultIcon: Icons.backspace_outlined,
              color: textColor,
              size: fontSize * 0.7,
            )
                : Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: onTap == null ? Colors.grey[300] : textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: Colors.grey[300]!),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Abbrechen',
              style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: isComplete ? _handleConfirm : null,
            icon: getAdaptiveIcon(
              iconName: isComplete ? 'check' : 'hourglass_empty',
              defaultIcon: isComplete ? Icons.check : Icons.hourglass_empty,
              color: Colors.white,
              size: 20,
            ),
            label: Text(
              isComplete ? 'Bestätigen' : 'Unvollständig',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isComplete ? successColor : Colors.grey[300],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: isComplete ? 2 : 0,
            ),
          ),
        ),
      ],
    );
  }
}