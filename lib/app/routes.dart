import 'package:flutter/material.dart';
import '../models/appliance_model.dart';
import '../models/analysis_model.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/profile_setup_screen.dart';
import '../screens/main_layout.dart';
import '../screens/home/add_appliance_screen.dart';
import '../screens/home/appliance_details_screen.dart';
import '../screens/home/analysis_screen.dart';
import '../screens/home/health_check_screen.dart';
import '../screens/home/result_screen.dart';
import '../screens/home/sensor_status_screen.dart';
import '../screens/settings/edit_profile_screen.dart';
import '../screens/chat/chatbot_screen.dart';

/// Centralized route generator for Flutter navigation.
class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String profileSetup = '/profile-setup';
  static const String home = '/home';
  static const String addAppliance = '/add-appliance';
  static const String applianceDetails = '/appliance-details';
  static const String sensorStatus = '/sensor-status';
  static const String analysisScreen = '/analysis-screen';
  static const String healthCheck = '/health-check';
  static const String resultScreen = '/result-screen';
  static const String editProfile = '/edit-profile';
  static const String chatbot = '/chatbot';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case profileSetup:
        return MaterialPageRoute(builder: (_) => const ProfileSetupScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const MainLayout());
      case addAppliance:
        return MaterialPageRoute(builder: (_) => const AddApplianceScreen());
      case applianceDetails:
        final appliance = settings.arguments as ApplianceModel;
        return MaterialPageRoute(
          builder: (_) => ApplianceDetailsScreen(appliance: appliance),
        );
      case sensorStatus:
        final appliance = settings.arguments as ApplianceModel;
        return MaterialPageRoute(
          builder: (_) => SensorStatusScreen(appliance: appliance),
        );
      case analysisScreen:
        final appliance = settings.arguments as ApplianceModel;
        return MaterialPageRoute(
          builder: (_) => AnalysisScreen(appliance: appliance),
        );
      case healthCheck:
        final appliance = settings.arguments as ApplianceModel;
        return MaterialPageRoute(
          builder: (_) => HealthCheckScreen(appliance: appliance),
        );
      case resultScreen:
        final result = settings.arguments as AnalysisModel?;
        return MaterialPageRoute(
          builder: (_) => ResultScreen(result: result),
        );
      case editProfile:
        return MaterialPageRoute(builder: (_) => const EditProfileScreen());
      case chatbot:
        final appliance = settings.arguments as ApplianceModel?;
        return MaterialPageRoute(
          builder: (_) => ChatbotScreen(initialAppliance: appliance),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
