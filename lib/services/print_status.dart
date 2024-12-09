import 'package:flutter/material.dart';

import '../constants.dart';

class PrintStatus {
  static String _currentStatus = "Initialisiere Drucker...";
  static StateSetter? _setStateCallback;

  static void _updateStatus(BuildContext context, String newStatus) {
    if (context.mounted) {
      _setStateCallback?.call(() {
        _currentStatus = newStatus;
      });
    }
  }

  static Future<void> show(BuildContext context, Future<void> Function() printFunction) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            _setStateCallback = setState;
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Container(
                padding: const EdgeInsets.all(20),
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 1.0, end: 1.2),
                      duration: const Duration(seconds: 1),
                      builder: (context, double value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: primaryAppColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.print,
                              size: 40,
                              color: primaryAppColor,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _currentStatus,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    LinearProgressIndicator(
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(primaryAppColor),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    try {
      await printFunction();
    } catch (e) {
      rethrow;
    } finally {
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }
}