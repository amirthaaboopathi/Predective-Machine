import 'package:flutter/material.dart';
import '../widgets/bottom_navigation.dart';
import 'home/home_screen.dart';
import 'analytics/analytics_screen.dart';
import 'results/results_screen.dart';
import 'alerts/alerts_screen.dart';
import 'settings/settings_screen.dart';

/// Main container layout holding the 5-tab bottom navigation and tab views.
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _navigateToAddAppliance() {
    Navigator.pushNamed(context, '/add-appliance');
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        onNavigateToAddAppliance: _navigateToAddAppliance,
        onNavigateToTab: _onTabSelected,
      ),
      const AnalyticsScreen(),
      const ResultsScreen(),
      const AlertsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: CustomBottomNavigation(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
      ),
    );
  }
}
