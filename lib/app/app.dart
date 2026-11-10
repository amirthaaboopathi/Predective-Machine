import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/theme_service.dart';
import 'theme.dart';
import 'routes.dart';

/// Root Application Widget configuring theme and routes.
class MyApplianceApp extends StatelessWidget {
  const MyApplianceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();

    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeService.themeMode,
          initialRoute: AppRoutes.splash,
          onGenerateRoute: AppRoutes.generateRoute,
        );
      },
    );
  }
}
