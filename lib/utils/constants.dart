import 'dart:convert';

class AppConstants {
  static const String appName = 'MyAppliance';
  static const String appSubtitle = 'Appliance Health Checker';

  // Supabase Configuration
  static const String supabaseUrl = 'https://jalicryunnjxmipuihwp.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_cAWNuGx3JYV1zfee1qMxEQ__15qt_3w';
  
  // Gemini AI Configuration
  static const String _defaultEncodedKey = 'QVEuQWI4Uk42STdrSmNucVNjZzViTlZRZ1YwTkMxYnhYMk9iZVg4VmV4OXVkLUpXenQwY2c=';
  
  static String get geminiApiKey {
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.isNotEmpty) return envKey;
    try {
      return utf8.decode(base64.decode(_defaultEncodedKey));
    } catch (_) {
      return '';
    }
  }

  static const String geminiModel = 'gemini-1.5-flash';
  static const String geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  // FastAPI Python Backend Configuration
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  // Appliance types list
  static const List<String> applianceTypes = [
    'Refrigerator',
    'Washing Machine',
    'Air Conditioner',
    'Television',
    'Fan',
    'Microwave',
    'Other',
  ];
}
