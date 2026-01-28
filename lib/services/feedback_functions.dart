//
// import 'dart:io';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:device_info_plus/device_info_plus.dart';
// import 'package:feedback/feedback.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'dart:io';
// import 'dart:math';
// import 'dart:typed_data';
// import 'package:firebase_storage/firebase_storage.dart';
//
// import 'package:flutter/foundation.dart' show kIsWeb;
// import 'package:flutter/cupertino.dart';
//
//
// late String currentPic;
// String generateRandomName() {
//   Random random = Random();
//   String randomName = '';
//
//   for (int i = 0; i < 10; i++) {
//     randomName += random.nextInt(10).toString();
//
//   }
//   return randomName;
// }
//   Future<String> globalUploadFeedback(String folderName,Uint8List feedbackScreenshot) async{
//
//
//     String fileName = '${generateRandomName()}.jpg';
//
//     Reference ref = FirebaseStorage.instance.ref().child('$folderName/$fileName');
//
//     UploadTask uploadTask = ref.putData(feedbackScreenshot);
//
//
//
//     var url = await (await uploadTask).ref.getDownloadURL();
//     currentPic = url.toString();
//
//     return currentPic;
//
//   }
//
// /// Prints the given feedback to the console.
// /// This is useful for debugging purposes.
// void consoleFeedbackFunction(
//     BuildContext context,
//     UserFeedback feedback,
//     ) {
//
//   if (feedback.extra != null) {
//
//   }
// }
//
// /// Shows an [AlertDialog] with the given feedback.
// /// This is useful for debugging purposes.
// void alertFeedbackFunction(
//
//     BuildContext outerContext,
//     UserFeedback feedback,
//     ) {
//
//   showDialog<void>(
//     context: outerContext,
//     builder: (context) {
//       return AlertDialog(
//         title: Text(feedback.text),
//         content: SingleChildScrollView(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               if (feedback.extra != null) Text(feedback.extra!.toString()),
//               Image.memory(
//                 feedback.screenshot,
//                 height: 600,
//                 width: 500,
//                 fit: BoxFit.contain,
//               ),
//             ],
//           ),
//         ),
//         actions: <Widget>[
//           TextButton(
//             child: const Text('Close'),
//             onPressed: () async {
//
//               await globalUploadFeedback("feedback",feedback.screenshot);
//
//             },
//           )
//         ],
//       );
//     },
//   );
// }
//
// Future<void> alertFeedbackFunction2(
//
//     String name,
//     String userID,
//
//     UserFeedback feedback,
//     String packageName,version,buildNumber,
//
//
//     ) async {
//   String model = "";
//   String manufacturer="";
//   String versionSDK="";
//   final FirebaseFirestore db= FirebaseFirestore.instance;
//
//
//               String url=  await globalUploadFeedback("feedback",feedback.screenshot);
//
//
//    final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
//   if(kIsWeb==false) {
//         if(Platform.isAndroid==true){Map androidBuildData= _readAndroidBuildData(await deviceInfoPlugin.androidInfo);
//           model= androidBuildData['model'];
//           manufacturer =  androidBuildData['manufacturer'];
//           versionSDK=androidBuildData['version.sdkInt'].toString();
//         }
//
//   if(Platform.isIOS==true)
//   {
//     Map iosBuildData= _readIosDeviceInfo(await deviceInfoPlugin.iosInfo);
//     model= iosBuildData['model'];
//     versionSDK=iosBuildData['systemVersion'];
//     manufacturer="Apple";
//
//   }
//   }else{
//     final deviceInfoPlugin = DeviceInfoPlugin();
//     final deviceInfo = await deviceInfoPlugin.deviceInfo;
//     final allInfo = deviceInfo.data;
//     manufacturer=allInfo['browserName'].toString();
//   }
//
//   db.collection('feedbacks').doc().set({'versionSKD':versionSDK,'model':model,'manufacturer':manufacturer,'packageName': packageName,'version':version,'buildNumber':buildNumber,'feedbackText':feedback.text,'userID':userID,'name':name,'screenshot':url,'timeStamp':FieldValue.serverTimestamp(),'alreadyChecked':false,'feedbackAnswerSendToUser':false},SetOptions(merge: true));
//   db.collection('total').doc('stats').set({'feedbackCounter': FieldValue.increment(1),},SetOptions(merge: true));
//
//
// }
//
//
// Map<String, dynamic> _readAndroidBuildData(AndroidDeviceInfo build) {
//   return <String, dynamic>{
//     'version.securityPatch': build.version.securityPatch,
//     'version.sdkInt': build.version.sdkInt,
//     'version.release': build.version.release,
//     'version.previewSdkInt': build.version.previewSdkInt,
//     'version.incremental': build.version.incremental,
//     'version.codename': build.version.codename,
//     'version.baseOS': build.version.baseOS,
//     'board': build.board,
//     'bootloader': build.bootloader,
//     'brand': build.brand,
//     'device': build.device,
//     'display': build.display,
//     'fingerprint': build.fingerprint,
//     'hardware': build.hardware,
//     'host': build.host,
//     'id': build.id,
//     'manufacturer': build.manufacturer,
//     'model': build.model,
//     'product': build.product,
//     'supported32BitAbis': build.supported32BitAbis,
//     'supported64BitAbis': build.supported64BitAbis,
//     'supportedAbis': build.supportedAbis,
//     'tags': build.tags,
//     'type': build.type,
//     'isPhysicalDevice': build.isPhysicalDevice,
//     'systemFeatures': build.systemFeatures,
//     'serialNumber': build.serialNumber,
//   };
// }
//
// Map<String, dynamic> _readIosDeviceInfo(IosDeviceInfo data) {
//   return <String, dynamic>{
//     'name': data.name,
//     'systemName': data.systemName,
//     'systemVersion': data.systemVersion,
//     'model': data.model,
//     'localizedModel': data.localizedModel,
//     'identifierForVendor': data.identifierForVendor,
//     'isPhysicalDevice': data.isPhysicalDevice,
//     'utsname.sysname:': data.utsname.sysname,
//     'utsname.nodename:': data.utsname.nodename,
//     'utsname.release:': data.utsname.release,
//     'utsname.version:': data.utsname.version,
//     'utsname.machine:': data.utsname.machine,
//   };
//
//
// }
//
