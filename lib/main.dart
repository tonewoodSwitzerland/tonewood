import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tonewood/services/firebase_options.dart';
import 'package:tonewood/services/languages.dart';
import 'authenticate/forget_screen.dart';
import 'authenticate/registration_screen.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter_sizer/flutter_sizer.dart';
import 'package:get/get.dart';
import '/../constants.dart';
import 'authenticate/login_screen.dart';
import '/../home/start_screen.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
//Future<void> main() async {
  // WidgetsFlutterBinding.ensureInitialized();
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );
  //  FirebaseFunctions.instanceFor(region: 'europe-west1');
  //
  //
  // runApp(           MyApp()); }

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    await Firebase.initializeApp();
  }

  runApp(
          MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FlutterSizer(
      builder: (context, orientation, screenType) {
        return BetterFeedback(
          child: GetMaterialApp(
            debugShowCheckedModeBanner: false,
            translations: LocalString(),
            locale: _getLocaleBasedOnDeviceSettings(context),
            // NEU: Füge localizationsDelegates hinzu
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            // NEU: Füge supportedLocales hinzu
            supportedLocales: const [
              Locale('en', 'US'),
              Locale('de', 'DE'),
              Locale('de', 'CH'),
              Locale('de', 'AT'),
            ],
            title: 'Tonewood Switzerland',
            theme: ThemeData(
              scaffoldBackgroundColor: Colors.white,
              cardColor: Colors.white,
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                ),
              ),



              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black87, textStyle: smallHeadline,
                ),
              ),
              dialogTheme: const DialogTheme(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
              ),

              colorScheme: ColorScheme.fromSeed(
                seedColor: primaryAppColor,
                surface: Colors.white,
              ),
              useMaterial3: true,
            ),
            initialRoute: LoginScreen.id,
            routes: {
              LoginScreen.id: (context) => const LoginScreen(),
              RegistrationScreen.id: (context) => const RegistrationScreen(),
              ForgetScreen.id: (context) => const ForgetScreen(),
              StartScreen.id: (context) => StartScreen(key: UniqueKey(),),
            },
            onGenerateRoute: (settings) {
              return MaterialPageRoute(
                builder: (BuildContext context) => const LoginScreen(),
              );
            },
            onUnknownRoute: (settings) {
              return MaterialPageRoute(
                builder: (context) => const LoginScreen(),
              );
            },
          ),
        );
      },
    );
  }

  Locale _getLocaleBasedOnDeviceSettings(BuildContext context) {
    String locale = View.of(context).platformDispatcher.locale.toString();
    if (locale != "de_DE" &&
        locale != "de_AT" &&
        locale != "de_CH" &&
        locale != "de_BE" &&
        locale != "de_LI" &&
        locale != "de_LU") {
      return const Locale('en', 'US');
    }
    return View.of(context).platformDispatcher.locale;
  }
}
