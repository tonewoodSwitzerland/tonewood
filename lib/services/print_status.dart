import 'package:another_brother/printer_info.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import 'icon_helper.dart';

class PrinterErrorHelper {
  static String getErrorMessage(dynamic error) {
    // Prüfe auf ERROR_NONE und gib leeren String zurück
    if (error is Map && error['errorCode']?['name'] == 'ERROR_NONE') {
      return ''; // Erfolgsfall = keine Fehlermeldung
    }

    // Der Rest der Methode bleibt wie vorher
    if (error is Map) {
      switch (error['errorCode']?['name']) {
        case 'ERROR_WRONG_LABEL':
          return 'Falsches Etikettenformat eingelegt.\nBitte überprüfen Sie die Etikettengröße.';
        case 'ERROR_PAPER_EMPTY':
          return 'Keine Etiketten eingelegt.';
        case 'ERROR_BATTERY_EMPTY':
          return 'Akku leer.';
        case 'ERROR_COMMUNICATION_ERROR':
          return 'Kommunikationsfehler mit dem Drucker.';
        case 'ERROR_PAPER_JAM':
          return 'Papierstau im Drucker.';
        case 'ERROR_COVER_OPEN':
          return 'Druckerdeckel ist offen.';
        case 'ERROR_BUSY':
          return 'Drucker beschäftigt.';
        default:
          return 'Druckerfehler: ${error['errorCode']?['name'] ?? "Unbekannt"}';
      }
    }
    return 'Druckerfehler: ${error.toString()}';
  }

  static bool isErrorStatus(dynamic printerStatus) {
    if (printerStatus is Map) {
      return printerStatus['errorCode']?['name'] != 'ERROR_NONE';
    }
    return true;
  }
}

class PrintStatus {
  static String _status = '';
  static bool _isDialogOpen = false;
  static StateSetter? _setStateCallback;

  static void updateStatus(String message) {
    _status = message;
    if (_isDialogOpen && _setStateCallback != null) {
      try {
        _setStateCallback!(() {});
      } catch (e) {
        print('Fehler beim Status Update: $e');
      }
    }
  }

  static void _reset() {
    _status = '';
    _isDialogOpen = false;
    _setStateCallback = null;
  }

  static Future<void> show(BuildContext context, Future<void> Function() callback) async {
    // Sicherstellen dass kein Dialog offen ist
    _reset();
    _isDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return WillPopScope(
          onWillPop: () async => false,
          child: StatefulBuilder(
            builder: (dialogContext, setState) {
              _setStateCallback = setState;

              return Dialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(  // Verhindert Overflow
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: primaryAppColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child:

                          getAdaptiveIcon(iconName: 'print', defaultIcon:
                            Icons.print,
                            size: 40,
                            color: primaryAppColor,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _status,
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
                ),
              );
            },
          ),
        );
      },
    );

    try {
      await callback();
      // Warte kurz damit die Erfolgsmeldung sichtbar ist
      await Future.delayed(const Duration(milliseconds: 500));
    } finally {
      if (_isDialogOpen && context.mounted) {
        Navigator.of(context).pop();
      }
      _reset();
    }
  }
}