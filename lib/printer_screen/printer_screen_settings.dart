import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../constants.dart';


void showPrinterScreenSettingsDialog(BuildContext context) async {
  bool saveOldData = false;
  // Abrufen der aktuellen Einstellungen aus der Datenbank
  //DocumentSnapshot<Map<String, dynamic>> settingsSnapshot = await FirebaseFirestore.instance.collection('companies').doc('100').get();
  //
  // if (settingsSnapshot.exists) {
  //   saveOldData = settingsSnapshot.data()?['clearPrinterValuesAfterInput'] ?? false;
  //
  // }
  //

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            title: Center(child: const Text('Einstellungen', style: headline4_0)),
            content: Container(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Platzhalter', style: smallestHeadline),
                          value: saveOldData,
                          onChanged: (bool value) async {
                            setState(() {
                              saveOldData = value;
                            });

                      //      await FirebaseFirestore.instance.collection('companies').doc('100').set({'clearPrinterValuesAfterInput': saveOldData}, SetOptions(merge: true));
                          },
                        ),


                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Schließen'),
              ),
            ],
          );
        },
      );
    },
  );
}
