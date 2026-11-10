import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'theme.dart';
import 'routes.dart';

/// Root Application Widget configuring theme and routes.
class MyApplianceApp extends StatelessWidget {
  const MyApplianceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}
