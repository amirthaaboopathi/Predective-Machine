import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages 1-to-1 hardware port bindings between physical sensor devices (e.g. COM3)
/// and individual appliances.
///
/// Ensures strict exclusivity:
/// - A COM port (hardware device) streams telemetry to ONE appliance only.
/// - When multiple appliances are created, each must be installed with its own
///   distinct hardware device / COM port to monitor it independently.
class HardwareMappingService extends ChangeNotifier {
  static final HardwareMappingService _instance = HardwareMappingService._internal();
  factory HardwareMappingService() => _instance;
  HardwareMappingService._internal();

  static const String _storageKey = 'appliance_hardware_bindings_v1';
  static const String defaultPort = 'COM3';

  // Map of applianceId -> portName (e.g. "uuid-123" -> "COM3")
  final Map<String, String> _applianceToPort = {};

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Map of applianceId -> portName
  Map<String, String> get bindings => Map.unmodifiable(_applianceToPort);

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _applianceToPort.clear();
        decoded.forEach((key, value) {
          if (value is String && value.isNotEmpty) {
            _applianceToPort[key] = value.toUpperCase();
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading hardware bindings: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Gets the assigned COM port for an appliance, or null if not hardware monitored.
  String? getPortForAppliance(String applianceId) {
    return _applianceToPort[applianceId];
  }

  /// Gets the appliance ID bound to a specific COM port (e.g. "COM3").
  String? getApplianceIdForPort(String portName) {
    final cleanPort = portName.toUpperCase().trim();
    for (final entry in _applianceToPort.entries) {
      if (entry.value.toUpperCase().trim() == cleanPort) {
        return entry.key;
      }
    }
    return null;
  }

  /// Returns true if the appliance is paired with any active hardware port.
  bool isApplianceMonitored(String applianceId) {
    return _applianceToPort.containsKey(applianceId) &&
        _applianceToPort[applianceId]!.isNotEmpty;
  }

  /// Binds an appliance to a specific hardware port (e.g. "COM3").
  ///
  /// Enforces: ONE APPLIANCE ONLY per hardware device!
  /// If another appliance was previously using this port, it will be automatically
  /// unlinked so telemetry is strictly directed to the newly assigned appliance.
  Future<void> bindApplianceToPort(String applianceId, String? portName) async {
    await init();

    if (portName == null || portName.trim().isEmpty || portName.toUpperCase() == 'NONE') {
      _applianceToPort.remove(applianceId);
    } else {
      final cleanPort = portName.toUpperCase().trim();

      // Check if another appliance was bound to this port and unlink it
      final existingApplianceId = getApplianceIdForPort(cleanPort);
      if (existingApplianceId != null && existingApplianceId != applianceId) {
        _applianceToPort.remove(existingApplianceId);
        debugPrint('Port $cleanPort reassigned from $existingApplianceId to $applianceId');
      }

      _applianceToPort[applianceId] = cleanPort;
    }

    await _save();
    notifyListeners();
  }

  /// Unbinds an appliance from hardware monitoring.
  Future<void> unbindAppliance(String applianceId) async {
    await init();
    if (_applianceToPort.containsKey(applianceId)) {
      _applianceToPort.remove(applianceId);
      await _save();
      notifyListeners();
    }
  }

  /// Checks if a port is currently assigned to any other appliance.
  bool isPortOccupied(String portName, {String? excludingApplianceId}) {
    final cleanPort = portName.toUpperCase().trim();
    for (final entry in _applianceToPort.entries) {
      if (entry.value == cleanPort && entry.key != excludingApplianceId) {
        return true;
      }
    }
    return false;
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_applianceToPort));
    } catch (e) {
      debugPrint('Error saving hardware bindings: $e');
    }
  }
}

