


import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_sizer/flutter_sizer.dart';

import 'package:universal_io/io.dart';


// Responsive Breakpoints
class ResponsiveBreakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

// Responsive Layout Helper
class ResponsiveLayout {
  static bool isMobile(double width) => width < ResponsiveBreakpoints.mobile;
  static bool isTablet(double width) => width >= ResponsiveBreakpoints.mobile && width < ResponsiveBreakpoints.desktop;
  static bool isDesktop(double width) => width >= ResponsiveBreakpoints.desktop;

  static double getContentWidth(double screenWidth) {
    if (screenWidth <= ResponsiveBreakpoints.mobile) return screenWidth;
    if (screenWidth <= ResponsiveBreakpoints.tablet) return screenWidth * 0.85;
    if (screenWidth <= ResponsiveBreakpoints.desktop) return screenWidth * 0.7;
    return 1200; // Maximum Breite für sehr große Bildschirme
  }

  static double getLoginWidth(double screenWidth) {
    if (isMobile(screenWidth)) return screenWidth * 0.9;
    if (isTablet(screenWidth)) return screenWidth * 0.7;
    return screenWidth * 0.4;
  }
  static double getIconSize(double screenWidth) {
    if (isMobile(screenWidth)) return 24.0;
    if (isTablet(screenWidth)) return 28.0;
    if (isDesktop(screenWidth)) return 32.0;
    return 24.0; // Standardgröße
  }
  static double getLogoSize(double screenWidth) {
    if (isMobile(screenWidth)) return screenWidth * 0.5;
    if (isTablet(screenWidth)) return screenWidth * 0.3;
    return screenWidth * 0.2;
  }
}
// Neue PlatformInfo Klasse
class PlatformInfo {
  static bool get isMobilePlatform => kIsWeb ? false : (Platform.isIOS || Platform.isAndroid);
  static bool get isDesktopPlatform => kIsWeb ? false : (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
  static bool get isWebPlatform => kIsWeb;

  static double getWebFactor(double screenWidth) {
    if (!isWebPlatform) return 1.0;
    if (screenWidth > ResponsiveBreakpoints.tablet) return 1.2;
    if (screenWidth > ResponsiveBreakpoints.mobile) return 1.1;
    return 1.0;
  }

  // Angepasste Icon-Größen für verschiedene Plattformen
  static double getIconSize(double baseSize, double screenWidth) {
    if (isMobilePlatform) return baseSize;
    if (isWebPlatform) return baseSize * getWebFactor(screenWidth);
    return baseSize * 1.2; // Etwas größer für Desktop
  }

  // Helper-Methode für Bottom Navigation Bar Icons
  static double getBottomNavIconSize(double screenWidth) {
    if (isMobilePlatform) return 24.0;
    if (isWebPlatform && screenWidth > ResponsiveBreakpoints.desktop) return 32.0;
    if (isWebPlatform && screenWidth > ResponsiveBreakpoints.tablet) return 28.0;
    return 24.0;
  }
}
// Überarbeitete Konstanten für responsives Design
class AppSizes {
  static double w = Adaptive.w(100);
  static double h = Adaptive.h(100);

  static double getHorizontalPadding(double width) {
    if (ResponsiveLayout.isMobile(width)) return 20;
    if (ResponsiveLayout.isTablet(width)) return 40;
    return 60;
  }

  static double getVerticalPadding(double width) {
    if (ResponsiveLayout.isMobile(width)) return 20;
    if (ResponsiveLayout.isTablet(width)) return 40;
    return 60;
  }
  static double getInputFieldHeight(double height) => height * 0.07;
  static double getButtonHeight(double height) => height * 0.06;
}


int calculateGridCount(double width) {
  if (width <= 600) {
    return 3;
  } else if (width >= 4000) {
    return 20; // Maximal 20 Spalten bei 4000 und mehr
  } else {
    // Linearer Anstieg zwischen 600 und 4000
    return ((width - 600) / 170).ceil() + 3;
  }
}

String platF= Platform.isIOS==true ||   Platform.isAndroid==true ? "mobile":"desktop";

double mobileFactor =kIsWeb==false?2:w>800?0.5:1;
double isMobile=kIsWeb==false?0:w>800?200:100;
double isHero=kIsWeb==false?0.3:w>800?0.8:0.3;
int isMobileGrid = kIsWeb == false ? 3 : w > 1400 ? 9 : w > 1200 ? 8 : w > 1000 ? 7 : w > 800 ? 6 : w > 600 ? 4 : 3;
int isMobileGridWoodList = kIsWeb == false ? 2 : w > 1400 ? 8 : w > 1200 ? 7 : w > 1000 ? 6 : w > 800 ? 5 : w > 600 ? 3 : 2;
const goldenColour=Color(0xFFD6BA73);
bool isMobilePackageDetail=kIsWeb==false?true:w>800?false:true;
int isMobilePackageDetailInt=kIsWeb==false?1:w>800?5:1;
GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class PackageConstant {
  static const barcodeFilePath =
      "packages/simple_barcode_scanner/assets/barcode.html";
  static const barcodeFileWebPath =
      "assets/packages/simple_barcode_scanner/assets/barcode.html";
}

String kScanPageTitle = 'Scan barcode/qrcode';


const kTextFieldDecoration=  InputDecoration(hintText: '...', contentPadding: EdgeInsets.symmetric(vertical: 5.0, horizontal: 5.0),
  border: OutlineInputBorder(borderSide: BorderSide(color: Colors.white30, width: 1.0), borderRadius: BorderRadius.all(Radius.circular(borderRadius),),
  ), disabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white, width: 1.0),  borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
  ), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color:  blackColor, width: 1.0), borderRadius: BorderRadius.all(Radius.circular(borderRadius)),),);

const kTextFieldDecorationTournament=  InputDecoration(hintText: '...', contentPadding: EdgeInsets.symmetric(vertical: 5.0, horizontal: 5.0), enabledBorder: InputBorder.none,
  border: OutlineInputBorder(borderSide: BorderSide(color: Colors.white, width: 1.0), borderRadius: BorderRadius.all(Radius.circular(borderRadius),),
  ), disabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white, width: 1.0),  borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
  ), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white, width: 1.0), borderRadius: BorderRadius.all(Radius.circular(borderRadius)),),);
String barcodeData = '';



const primaryAppColor= Color(0xFF0F4A29);
const secondaryAppColor= Color(0xFF3E9C37);
final Color lightGrayColor = const Color(0xFFF5F5F5);
const textColor= Color.fromRGBO(215,149,76,1);
const blackColor= Color.fromRGBO(39,38,36,1);
const double borderRadius=10;
const kLabelTextStyleT1small  = TextStyle(fontSize: 10.0, fontWeight: FontWeight.w900, color:  blackColor);
const kLabelTextStyleT2small  = TextStyle(fontSize: 10.0, fontWeight: FontWeight.w900, color: Colors.redAccent);
const kActiveCardColour = Colors.white;
const labelButtons  = TextStyle( fontWeight: FontWeight.w400, color: standardTextColor);
const regularText  = TextStyle(fontWeight: FontWeight.w500,color: standardTextColor);
const barHeadline  = TextStyle( fontWeight: FontWeight.w500, color: Color(0xFFE6E6E6));
const smallHeadline  = TextStyle( fontWeight: FontWeight.w700, color: standardTextColor);
const smallestHeadline  = TextStyle( fontWeight: FontWeight.w700, fontSize:12, color: standardTextColor);
const headline4_0=TextStyle(color: Colors.black87, fontSize:25,fontWeight: FontWeight.w700 );
const headline20=TextStyle(color: Colors.black87, fontSize:20,fontWeight: FontWeight.w700 );
const smallHeadline4_0 =  TextStyle( fontWeight: FontWeight.w700, fontSize:15,color: standardTextColor);
const smallTextField =  TextStyle( fontWeight: FontWeight.w500, fontSize:12,color: standardTextColor);
const barHeadline4_0  = TextStyle( fontWeight: FontWeight.w500, color: whiteColour);
const resultInputNumbers  = TextStyle( fontWeight: FontWeight.w900, color: standardTextColor,fontSize:60);
const regularText4_0= TextStyle( fontWeight: FontWeight.w400, color: standardTextColor,fontSize:15);
const tileText4_0= TextStyle( fontWeight: FontWeight.w400, color: standardTextColor,fontSize:12);
const kInactiveCardColour = Colors.transparent;
const whiteColour=Colors.white;
const basicBackgroundColour=Colors.black87;
//const basicBackgroundColour=Colors.black54;

const iconColour=Colors.black87;
const iconInfoColour=Colors.blueGrey;
const iconInfoSize=0.04;
const lighterBlackColour=Colors.black38;
const darkerBlackColour=Colors.black87;

const highlightColour=primaryAppColor;
const textFactor10=0.010;
const textFactor12=0.012;
const textFactor13=0.013;
const textFactor15=0.015;
const textFactor20=0.020;
const textFactor25=0.025;
const textFactor30=0.030;
const textFactor35=0.035;
const smallIconFactor=0.03;
const iconFactor020=0.020;
const iconFactor025=0.025;
const textFactor18=0.018;
const minBrowserHeight=650;
const standardTextColor=Colors.black87;
const kIsWebApp=kIsWeb;
const kActiveCardColourStyle = Color.fromRGBO(84, 84, 84, 1);
const kInactiveCardColourStyle = Colors.white10;
double h=Adaptive.h(100);
double w=Adaptive.w(100);
double ratio=h/w;
double newBorderValue=(h-w)*0.5;

class SizeConfig {
  static late MediaQueryData _mediaQueryData;
  static late double screenWidth;
  static late double screenHeight;
  static late double blockSizeHorizontal;
  static late double blockSizeVertical;


  void init(BuildContext context) {_mediaQueryData = MediaQuery.of(context);


  screenWidth = _mediaQueryData.size.width;
  screenHeight = _mediaQueryData.size.height;
  blockSizeHorizontal = screenWidth / 100;
  blockSizeVertical = screenHeight / 100;
  }

}
class AppToast {
  static void show({required String message, required double height}) {
    Fluttertoast.showToast(
      backgroundColor: primaryAppColor,
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.SNACKBAR,
      timeInSecForIosWeb: 2,
      textColor: Colors.white,
      fontSize: height * textFactor15,
    );
  }
}
