import 'package:flutter/material.dart';
import 'package:tonewood/analytics/production/production_screen.dart';
import 'package:tonewood/analytics/sales/sales_screen.dart';
import '../analytics/roundwood/roundwood_screen.dart';
import '../constants.dart';
import '../production/production_screen_analytics_new.dart';
import '../services/icon_helper.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  AnalyticsScreenState createState() => AnalyticsScreenState();
}

class AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopLayout = screenWidth > ResponsiveBreakpoints.tablet;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0, // Entfernt den oberen Teil der AppBar
        bottom: TabBar(
          controller: _tabController,
          tabs:  [
            Tab(
              icon:
              getAdaptiveIcon(iconName: 'forest', defaultIcon: Icons.forest,),
              text: 'Rundholz',
            ),
            Tab(
              icon:   getAdaptiveIcon(iconName: 'shopping_cart', defaultIcon: Icons.shopping_cart,),

              text: 'Verkauf',
            ),
            Tab(
            icon:  getAdaptiveIcon(iconName: 'precision_manufacturing', defaultIcon: Icons.precision_manufacturing,),
              text: 'Produktion',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          RoundwoodScreen(isDesktopLayout: isDesktopLayout),
          SalesScreenAnalytics(isDesktopLayout: isDesktopLayout),
          ProductionAnalyticsScreen(isDesktopLayout: isDesktopLayout)
        ],
      ),
    );
  }
}