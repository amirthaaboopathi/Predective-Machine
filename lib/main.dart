import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'utils/constants.dart';
import 'services/hardware_mapping_service.dart';
import 'services/sensor_service.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    publishableKey: AppConstants.supabaseAnonKey,
  );

  await HardwareMappingService().init();
  await SensorService().init();
  await ThemeService().init();

  runApp(const MyApplianceApp());
}
