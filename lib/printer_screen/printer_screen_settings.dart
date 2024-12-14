
import 'package:flutter/material.dart';

import '../constants.dart';


void showPrinterScreenSettingsDialog(BuildContext context) async {
  bool saveOldData = false;


  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            title: const Center(child: Text('Einstellungen', style: headline4_0)),
            content: SizedBox(
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
