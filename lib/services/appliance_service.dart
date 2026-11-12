import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/appliance_model.dart';
import 'hardware_mapping_service.dart';

/// Service managing physical appliances with offline-first local persistence
/// and automatic cloud synchronization with Supabase.
class ApplianceService extends ChangeNotifier {
  static final ApplianceService _instance = ApplianceService._internal();
  factory ApplianceService() => _instance;
  ApplianceService._internal();

  static const String _localStorageKey = 'local_registered_appliances_v2';

  final List<ApplianceModel> _appliances = [];
  bool _isLoading = false;
  bool _isInitialized = false;

  SupabaseClient get _supabase => Supabase.instance.client;

  List<ApplianceModel> get appliances => List.unmodifiable(_appliances);
  bool get hasAppliances => _appliances.isNotEmpty;
  bool get isLoading => _isLoading;

  /// Loads locally stored appliances from disk.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await HardwareMappingService().init();
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        _appliances.clear();
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            final id = item['id']?.toString() ?? '';
            final port = HardwareMappingService().getPortForAppliance(id) ?? item['hardware_port'];
            _appliances.add(ApplianceModel.fromMap(item, hardwarePort: port));
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading local appliances: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _saveToLocalDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _appliances.map((a) {
        final map = a.toMap();
        if (a.hardwarePort != null) {
          map['hardware_port'] = a.hardwarePort;
        }
        return map;
      }).toList();
      await prefs.setString(_localStorageKey, jsonEncode(list));
    } catch (e) {
      debugPrint('Error saving appliances to disk: $e');
    }
  }

  /// Fetches registered appliances from local storage and Supabase if authenticated.
  Future<void> fetchAppliances() async {
    _isLoading = true;
    notifyListeners();

    try {
      await init();

      final user = _supabase.auth.currentUser;
      if (user != null) {
        final response = await _supabase
            .from('appliances')
            .select()
            .eq('user_id', user.id)
            .order('created_at', ascending: false);

        final data = response as List;
        if (data.isNotEmpty) {
          _appliances.clear();
          for (final item in data) {
            final rawMap = Map<String, dynamic>.from(item);
            final id = rawMap['id']?.toString() ?? '';
            final port = HardwareMappingService().getPortForAppliance(id);
            _appliances.add(ApplianceModel.fromMap(rawMap, hardwarePort: port));
          }
          await _saveToLocalDisk();
        }
      }
    } catch (e) {
      debugPrint('Notice: Cloud appliance fetch skipped or failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Registers a new appliance, saving to local disk and cloud (if authenticated).
  Future<ApplianceModel> addAppliance(
    ApplianceModel appliance, {
    String? assignedPort,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = _supabase.auth.currentUser;
      final effectiveUserId = user?.id ?? 'local_user';
      final port = assignedPort ?? appliance.hardwarePort ?? 'COM3';

      final applianceWithUser = appliance.copyWith(
        userId: effectiveUserId,
        hardwarePort: port == 'None' ? null : port,
      );

      ApplianceModel savedAppliance = applianceWithUser;

      // Attempt cloud insert if authenticated
      if (user != null) {
        try {
          final payload = applianceWithUser.toMap();
          final response = await _supabase
              .from('appliances')
              .insert(payload)
              .select()
              .single();

          final id = response['id']?.toString() ?? applianceWithUser.id;
          savedAppliance = ApplianceModel.fromMap(
            Map<String, dynamic>.from(response),
            hardwarePort: port == 'None' ? null : port,
          );
          if (port != 'None') {
            await HardwareMappingService().bindApplianceToPort(id, port);
          }
        } catch (e) {
          debugPrint('Notice: Cloud insert skipped, storing locally: $e');
          if (port != 'None') {
            await HardwareMappingService().bindApplianceToPort(savedAppliance.id, port);
          }
        }
      } else {
        if (port != 'None') {
          await HardwareMappingService().bindApplianceToPort(savedAppliance.id, port);
        }
      }

      _appliances.insert(0, savedAppliance);
      await _saveToLocalDisk();
      return savedAppliance;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 1-click helper to register preset household appliances.
  Future<ApplianceModel> registerPreset({
    required String type,
    required String name,
    String? brand,
  }) async {
    final newAppliance = ApplianceModel(
      id: 'app_${DateTime.now().millisecondsSinceEpoch}',
      userId: _supabase.auth.currentUser?.id ?? 'local_user',
      name: name,
      type: type,
      brand: brand ?? 'Smart Device',
      modelNumber: 'SM-2026',
      addedAt: DateTime.now(),
      hardwarePort: 'COM3',
    );
    return addAppliance(newAppliance, assignedPort: 'COM3');
  }

  /// Binds or reassigns a hardware port (e.g. COM3) to a specific appliance.
  Future<void> setApplianceHardwarePort(String applianceId, String? port) async {
    await HardwareMappingService().bindApplianceToPort(applianceId, port);

    for (int i = 0; i < _appliances.length; i++) {
      if (_appliances[i].id == applianceId) {
        _appliances[i] = _appliances[i].copyWith(hardwarePort: port);
      } else if (port != null && _appliances[i].hardwarePort == port) {
        _appliances[i] = _appliances[i].copyWith(hardwarePort: null);
      }
    }
    await _saveToLocalDisk();
    notifyListeners();
  }

  ApplianceModel? getApplianceById(String id) {
    try {
      return _appliances.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> removeAppliance(String id) async {
    try {
      await HardwareMappingService().unbindAppliance(id);
      final user = _supabase.auth.currentUser;
      if (user != null) {
        try {
          await _supabase
              .from('appliances')
              .delete()
              .eq('id', id)
              .eq('user_id', user.id);
        } catch (_) {}
      }

      _appliances.removeWhere((item) => item.id == id);
      await _saveToLocalDisk();
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing appliance: $e');
    }
  }

  void clear() {
    _appliances.clear();
    notifyListeners();
  }
}
