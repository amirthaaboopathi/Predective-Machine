import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sensor_reading_model.dart';
import '../models/appliance_health_metrics.dart';
import '../models/appliance_model.dart';

/// Service managing retrieval, calculation, local persistence, and cloud recording
/// of telemetry sensor readings.
class SensorService extends ChangeNotifier {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  static const String _localStorageKey = 'myappliance_stored_readings_cache_v2';
  static const int _maxInMemoryReadings = 1500;
  static const int _maxLocalDiskReadings = 300;

  final Map<String, List<SensorReadingModel>> _readingsMap = {};
  final List<SensorReadingModel> _allReadings = [];
  final Map<String, bool> _loadingMap = {};
  final Map<String, String?> _errorMap = {};

  bool _isInitialized = false;
  bool _isFetchingAll = false;
  String? _fetchAllError;
  DateTime? _lastPersistTime;

  SupabaseClient get _supabase => Supabase.instance.client;

  List<SensorReadingModel> get allReadings => List.unmodifiable(_allReadings);
  bool get isFetchingAll => _isFetchingAll;
  String? get fetchAllError => _fetchAllError;
  bool get isInitialized => _isInitialized;

  /// Overall fleet health metrics aggregated across all retrieved sensor readings.
  ApplianceHealthMetrics get overallFleetMetrics =>
      ApplianceHealthMetrics.fromReadings(_allReadings);

  /// Initializes local cache from disk and ensures baseline readings exist.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        _allReadings.clear();
        _readingsMap.clear();

        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            final reading = SensorReadingModel.fromMap(item);
            _insertReadingInMemory(reading);
          }
        }
      }

      // If no readings exist at all, populate baseline telemetry
      if (_allReadings.isEmpty) {
        _seedInitialBaselineTelemetry();
      }
    } catch (e) {
      debugPrint('Error loading cached sensor readings: $e');
      if (_allReadings.isEmpty) {
        _seedInitialBaselineTelemetry();
      }
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

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
    // Fallback to all readings if single device
    if (_readingsMap.isEmpty && _allReadings.isNotEmpty) {
      return List.unmodifiable(_allReadings);
    }
    return const [];
  }

  /// Returns the latest single sensor reading for an appliance.
  SensorReadingModel? getLatestReadingForAppliance(
    String applianceId, [
    String? applianceName,
  ]) {
    final readings = getReadingsForAppliance(applianceId, applianceName);
    return readings.isNotEmpty ? readings.first : (_allReadings.isNotEmpty ? _allReadings.first : null);
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

  /// Directly ingests a live telemetry reading arriving from the hardware (COM3 or Simulation),
  /// stores it immediately into memory and local storage, and notifies all listening UI screens.
  SensorReadingModel addLiveTelemetryReading({
    required String applianceId,
    required String applianceName,
    required double temperature,
    required double vibration,
    required double sound,
    DateTime? recordedAt,
  }) {
    final effectiveTime = recordedAt ?? DateTime.now();
    final reading = SensorReadingModel(
      id: 'telemetry_${effectiveTime.millisecondsSinceEpoch}',
      applianceId: applianceId.isNotEmpty ? applianceId : 'main_appliance',
      applianceName: applianceName.isNotEmpty ? applianceName : 'Smart Appliance',
      temperature: double.parse(temperature.toStringAsFixed(1)),
      vibration: double.parse(vibration.toStringAsFixed(2)),
      sound: double.parse(sound.toStringAsFixed(1)),
      recordedAt: effectiveTime,
    );

    _insertReadingInMemory(reading);
    _persistLocalReadingsThrottled();
    notifyListeners();

    return reading;
  }

  void _insertReadingInMemory(SensorReadingModel reading) {
    _allReadings.insert(0, reading);
    if (_allReadings.length > _maxInMemoryReadings) {
      _allReadings.removeLast();
    }

    if (reading.applianceId.isNotEmpty) {
      _readingsMap.putIfAbsent(reading.applianceId, () => []).insert(0, reading);
      if (_readingsMap[reading.applianceId]!.length > _maxInMemoryReadings) {
        _readingsMap[reading.applianceId]!.removeLast();
      }
    }

    if (reading.applianceName.isNotEmpty) {
      final nameKey = reading.applianceName.toLowerCase();
      _readingsMap.putIfAbsent(nameKey, () => []).insert(0, reading);
      if (_readingsMap[nameKey]!.length > _maxInMemoryReadings) {
        _readingsMap[nameKey]!.removeLast();
      }
    }
  }

  /// Throttled local disk persistence to minimize I/O overhead.
  void _persistLocalReadingsThrottled() {
    final now = DateTime.now();
    if (_lastPersistTime != null &&
        now.difference(_lastPersistTime!).inSeconds < 4) {
      return;
    }
    _lastPersistTime = now;
    _saveReadingsToLocalDisk();
  }

  Future<void> _saveReadingsToLocalDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final toSave = _allReadings.take(_maxLocalDiskReadings).map((r) => r.toMap()).toList();
      await prefs.setString(_localStorageKey, jsonEncode(toSave));
    } catch (e) {
      debugPrint('Failed to persist readings to disk: $e');
    }
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
          .order('recorded_at', ascending: false)
          .limit(200);

      final data = response as List;
      if (data.isNotEmpty) {
        _allReadings.clear();
        _readingsMap.clear();

        for (final item in data) {
          final reading = SensorReadingModel.fromMap(Map<String, dynamic>.from(item));
          _insertReadingInMemory(reading);
        }
        await _saveReadingsToLocalDisk();
      } else if (_allReadings.isEmpty) {
        await init();
      }

      return _allReadings;
    } catch (e, stackTrace) {
      debugPrint('Error fetching all sensor readings: $e');
      debugPrintStack(stackTrace: stackTrace);
      _fetchAllError = 'Failed to load telemetry readings from Supabase: $e';
      if (_allReadings.isEmpty) {
        await init();
      }
      return _allReadings;
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
          .order('recorded_at', ascending: false)
          .limit(100);

      final data = response as List;
      if (data.isNotEmpty) {
        final readings = data.map((item) {
          return SensorReadingModel.fromMap(Map<String, dynamic>.from(item));
        }).toList();

        _readingsMap[applianceId] = readings;
      }

      return _readingsMap[applianceId] ?? [];
    } catch (e) {
      debugPrint('Error fetching sensor readings for $applianceId: $e');
      _errorMap[applianceId] = 'Failed to fetch readings: $e';
      return _readingsMap[applianceId] ?? [];
    } finally {
      _loadingMap[applianceId] = false;
      notifyListeners();
    }
  }

  /// Inserts a new sensor telemetry reading into public.sensor_readings in Supabase
  /// and updates local cache.
  Future<SensorReadingModel> recordSensorReading({
    required String applianceId,
    required String applianceName,
    required double temperature,
    required double vibration,
    required double sound,
  }) async {
    final reading = addLiveTelemetryReading(
      applianceId: applianceId,
      applianceName: applianceName,
      temperature: temperature,
      vibration: vibration,
      sound: sound,
    );

    // Sync to Supabase in background
    try {
      final payload = {
        'appliance_id': applianceId,
        'appliance_name': applianceName,
        'temperature': temperature,
        'vibration': vibration,
        'sound': sound,
        'recorded_at': reading.recordedAt.toIso8601String(),
      };

      await _supabase.from('sensor_readings').insert(payload);
    } catch (e) {
      debugPrint('Notice: Cloud sync skipped or restricted by policy: $e');
    }

    return reading;
  }

  /// Seeds realistic initial baseline telemetry points so charts have trendlines on first boot.
  void _seedInitialBaselineTelemetry() {
    final now = DateTime.now();
    final rand = Random(42);

    for (int i = 24; i >= 0; i--) {
      final time = now.subtract(Duration(minutes: i * 15));
      final temp = 27.5 + sin(i * 0.4) * 3.5 + rand.nextDouble() * 1.5;
      final vib = 0.16 + cos(i * 0.3).abs() * 0.08 + rand.nextDouble() * 0.04;
      final sound = 44.0 + sin(i * 0.5) * 6.0 + rand.nextDouble() * 4.0;

      final reading = SensorReadingModel(
        id: 'baseline_$i',
        applianceId: 'main_appliance',
        applianceName: 'Smart Appliance',
        temperature: double.parse(temp.toStringAsFixed(1)),
        vibration: double.parse(vib.toStringAsFixed(2)),
        sound: double.parse(sound.toStringAsFixed(1)),
        recordedAt: time,
      );

      _insertReadingInMemory(reading);
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
