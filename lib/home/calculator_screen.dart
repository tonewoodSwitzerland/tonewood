import 'package:flutter/material.dart';
import '../constants.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({required Key key}) : super(key: key);

  @override
  CalculatorScreenState createState() => CalculatorScreenState();
}

class CalculatorScreenState extends State<CalculatorScreen> {
  final TextEditingController _radiusController = TextEditingController();
  final TextEditingController _lengthController = TextEditingController();
  double? _volume;

  @override
  void initState() {
    super.initState();
  }

  CalculatorScreenState();

  void _calculateVolume() {
    final double diameter = double.tryParse(_radiusController.text) ?? 0;
    final double length = double.tryParse(_lengthController.text) ?? 0;
    final double volume = pi * pow(diameter/100, 2) /4 * length;

    setState(() {
      _volume = volume;
    });
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
    final auth3 = FirebaseAuth.instance;
    User? user = auth3.currentUser;

    return user?.uid == null
        ? const Center(child: CircularProgressIndicator())
        : Scaffold(
      resizeToAvoidBottomInset: false,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Text(
              "Berechnung des Holzvolumens",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _volume == null
                ? Container()
                : Text(
              "Volumen: ${_volume!.toStringAsFixed(2)} m³",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _radiusController,
              decoration: const InputDecoration(
                labelText: "Durchmesser in cm",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _lengthController,
              decoration: const InputDecoration(
                labelText: "Länge in m",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _calculateVolume,
              child: const Text("Berechnen"),
            ),
            const SizedBox(height: 20),

          ],
        ),
      ),
    );
  }
}
