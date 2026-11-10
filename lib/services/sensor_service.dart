import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sensor_reading_model.dart';
import '../models/appliance_health_metrics.dart';
import '../models/appliance_model.dart';

/// Service managing retrieval, calculation, and recording of telemetry sensor readings from Supabase.
class SensorService extends ChangeNotifier {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  final Map<String, List<SensorReadingModel>> _readingsMap = {};
  final List<SensorReadingModel> _allReadings = [];
  final Map<String, bool> _loadingMap = {};
  final Map<String, String?> _errorMap = {};

  bool _isFetchingAll = false;
  String? _fetchAllError;

  SupabaseClient get _supabase => Supabase.instance.client;

  List<SensorReadingModel> get allReadings => List.unmodifiable(_allReadings);
  bool get isFetchingAll => _isFetchingAll;
  String? get fetchAllError => _fetchAllError;

  /// Overall fleet health metrics aggregated across all retrieved sensor readings.
  ApplianceHealthMetrics get overallFleetMetrics =>
      ApplianceHealthMetrics.fromReadings(_allReadings);

  /// Retrieves stored sensor readings for an appliance ID (or name fallback).
  List<SensorReadingModel> getReadingsForAppliance(
    String applianceId, [
    String? applianceName,
  ]) {
    if (_readingsMap.containsKey(applianceId) &&
        _readingsMap[applianceId]!.isNotEmpty) {
      return List.unmodifiable(_readingsMap[applianceId]!);
    }
    if (applianceName != null &&
        applianceName.isNotEmpty &&
        _readingsMap.containsKey(applianceName.toLowerCase())) {
      return List.unmodifiable(_readingsMap[applianceName.toLowerCase()]!);
    }
    return const [];
  }

  /// Returns the latest single sensor reading for an appliance.
  SensorReadingModel? getLatestReadingForAppliance(
    String applianceId, [
    String? applianceName,
  ]) {
    final readings = getReadingsForAppliance(applianceId, applianceName);
    return readings.isNotEmpty ? readings.first : null;
  }

  /// Indicates if readings are actively being fetched for an appliance ID.
  bool isLoading(String applianceId) {
    return _loadingMap[applianceId] ?? false;
  }

  /// Returns error message if last fetch failed for an appliance ID.
  String? getError(String applianceId) {
    return _errorMap[applianceId];
  }

  /// Calculates dynamically normalized health metrics from retrieved readings.
  ApplianceHealthMetrics getHealthMetricsForAppliance(
    String applianceId, [
    String? applianceName,
  ]) {
    final readings = getReadingsForAppliance(applianceId, applianceName);
    return ApplianceHealthMetrics.fromReadings(readings);
  }

  /// Fetches ALL telemetry sensor readings across all appliances from Supabase public.sensor_readings.
  Future<List<SensorReadingModel>> fetchAllSensorReadings() async {
    _isFetchingAll = true;
    _fetchAllError = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('sensor_readings')
          .select()
          .order('recorded_at', ascending: false);

      final data = response as List;
      _allReadings.clear();
      _readingsMap.clear();

      for (final item in data) {
        final reading =
            SensorReadingModel.fromMap(Map<String, dynamic>.from(item));
        _allReadings.add(reading);

        if (reading.applianceId.isNotEmpty) {
          _readingsMap
              .putIfAbsent(reading.applianceId, () => [])
              .add(reading);
        }
        if (reading.applianceName.isNotEmpty) {
          _readingsMap
              .putIfAbsent(reading.applianceName.toLowerCase(), () => [])
              .add(reading);
        }
      }

      return _allReadings;
    } catch (e, stackTrace) {
      debugPrint('Error fetching all sensor readings: $e');
      debugPrintStack(stackTrace: stackTrace);
      _fetchAllError = 'Failed to load telemetry readings from Supabase: $e';
      return [];
    } finally {
      _isFetchingAll = false;
      notifyListeners();
    }
  }

  /// Fetches sensor readings for a specific appliance_id from public.sensor_readings.
  Future<List<SensorReadingModel>> fetchSensorReadings(String applianceId) async {
    _loadingMap[applianceId] = true;
    _errorMap[applianceId] = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('sensor_readings')
          .select()
          .eq('appliance_id', applianceId)
          .order('recorded_at', ascending: false);

      final data = response as List;
      final readings = data.map((item) {
        return SensorReadingModel.fromMap(Map<String, dynamic>.from(item));
      }).toList();

      _readingsMap[applianceId] = readings;
      return readings;
    } catch (e, stackTrace) {
      debugPrint('Sensor data error for $applianceId: $e');
      debugPrintStack(stackTrace: stackTrace);
      _errorMap[applianceId] = 'Failed to load sensor readings';
      return [];
    } finally {
      _loadingMap[applianceId] = false;
      notifyListeners();
    }
  }

  /// Inserts a new sensor telemetry reading into public.sensor_readings in Supabase
  /// and updates local memory cache with zero blocking lag.
  Future<SensorReadingModel> recordSensorReading({
    required String applianceId,
    required String applianceName,
    required double temperature,
    required double vibration,
    required double sound,
  }) async {
    try {
      final payload = {
        'appliance_id': applianceId,
        'appliance_name': applianceName,
        'temperature': temperature,
        'vibration': vibration,
        'sound': sound,
        'recorded_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('sensor_readings')
          .insert(payload)
          .select()
          .single();

      final reading = SensorReadingModel.fromMap(Map<String, dynamic>.from(response));

      // Optimistic cache update
      _allReadings.insert(0, reading);
      _readingsMap.putIfAbsent(applianceId, () => []).insert(0, reading);
      if (applianceName.isNotEmpty) {
        _readingsMap.putIfAbsent(applianceName.toLowerCase(), () => []).insert(0, reading);
      }

      notifyListeners();
      return reading;
    } catch (e) {
      debugPrint('Failed to record sensor reading: $e');
      rethrow;
    }
  }

  /// Helper to record realistic sample telemetry if an appliance has no readings in Supabase.
  Future<void> simulateTelemetryReading(ApplianceModel appliance) async {
    final rand = Random();
    double temp;
    double vib;
    double sound;

    switch (appliance.type.toLowerCase()) {
      case 'refrigerator':
        temp = 35.0 + rand.nextDouble() * 15.0; // 35 - 50°C
        vib = 0.15 + rand.nextDouble() * 0.15; // 0.15 - 0.30
        sound = 38.0 + rand.nextDouble() * 14.0; // 38 - 52 dB
        break;
      case 'washing machine':
        temp = 28.0 + rand.nextDouble() * 18.0; // 28 - 46°C
        vib = 0.25 + rand.nextDouble() * 0.35; // 0.25 - 0.60
        sound = 50.0 + rand.nextDouble() * 22.0; // 50 - 72 dB
        break;
      case 'air conditioner':
        temp = 32.0 + rand.nextDouble() * 20.0; // 32 - 52°C
        vib = 0.18 + rand.nextDouble() * 0.22; // 0.18 - 0.40
        sound = 42.0 + rand.nextDouble() * 18.0; // 42 - 60 dB
        break;
      case 'microwave':
        temp = 40.0 + rand.nextDouble() * 22.0; // 40 - 62°C
        vib = 0.12 + rand.nextDouble() * 0.18; // 0.12 - 0.30
        sound = 52.0 + rand.nextDouble() * 15.0; // 52 - 67 dB
        break;
      default:
        temp = 30.0 + rand.nextDouble() * 15.0;
        vib = 0.20 + rand.nextDouble() * 0.20;
        sound = 45.0 + rand.nextDouble() * 15.0;
    }

    await recordSensorReading(
      applianceId: appliance.id,
      applianceName: appliance.name,
      temperature: double.parse(temp.toStringAsFixed(1)),
      vibration: double.parse(vib.toStringAsFixed(2)),
      sound: double.parse(sound.toStringAsFixed(1)),
    );
  }

  /// Clears cached sensor readings.
  void clear() {
    _readingsMap.clear();
    _allReadings.clear();
    _loadingMap.clear();
    _errorMap.clear();
    _isFetchingAll = false;
    _fetchAllError = null;
    notifyListeners();
  }
}
