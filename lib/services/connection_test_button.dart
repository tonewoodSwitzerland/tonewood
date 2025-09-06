import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

import 'icon_helper.dart';

class ConnectionTestButton extends StatelessWidget {
  const ConnectionTestButton({super.key});

  Future<void> _testConnection(BuildContext context) async {
    try {
      // 1. Debug-Modus Check
      print('Debug mode: ${kDebugMode}');

      // 2. Netzwerk-Check
      try {
        final result = await InternetAddress.lookup('192.168.178.40');
        print('Network check result: ${result.first.address}');
      } catch (e) {
        print('Network check failed: $e');
      }

      // 3. Firebase Functions Instanz
      print('Creating Firebase Functions instance...');
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

      // 4. Emulator Setup
      print('Setting up emulator connection...');
      functions.useFunctionsEmulator('192.168.178.40', 5001);

      // 5. Callable erstellen
      print('Creating callable...');
      final callable = functions.httpsCallable(
        'simpleTest',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 30),
        ),
      );

      // 6. Funktionsaufruf
      print('Calling function...');
      final result = await callable.call({
        'timestamp': DateTime.now().toIso8601String(),
      });

      // 7. Erfolg!
      print('Success! Result: ${result.data}');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test erfolgreich!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }

    } catch (e, stack) {
      // Detaillierte Fehlerausgabe
      print('Error details:');
      print('Type: ${e.runtimeType}');
      print('Message: $e');
      print('Stack trace:\n$stack');

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Verbindungsfehler'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Fehlertyp: ${e.runtimeType}'),
                  const SizedBox(height: 8),
                  Text('Nachricht: $e'),
                  const SizedBox(height: 16),
                  const Text('Stack Trace:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(stack.toString()),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _testConnection(context),
      icon:  getAdaptiveIcon(iconName: 'network_check',defaultIcon:Icons.network_check),
      label: const Text('Verbindungstest'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }
}