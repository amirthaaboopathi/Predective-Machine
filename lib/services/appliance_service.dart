import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/appliance_model.dart';
import 'hardware_mapping_service.dart';

class ApplianceService extends ChangeNotifier {
  static final ApplianceService _instance = ApplianceService._internal();

  factory ApplianceService() => _instance;

  ApplianceService._internal();

  final List<ApplianceModel> _appliances = [];

  bool _isLoading = false;

  SupabaseClient get _supabase {
    return Supabase.instance.client;
  }

  List<ApplianceModel> get appliances => List.unmodifiable(_appliances);

  bool get hasAppliances => _appliances.isNotEmpty;

  bool get isLoading => _isLoading;

  Future<void> fetchAppliances() async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        _appliances.clear();
        return;
      }

      await HardwareMappingService().init();

      final response = await _supabase
          .from('appliances')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final data = response as List;

      _appliances.clear();

      for (final item in data) {
        final rawMap = Map<String, dynamic>.from(item);
        final id = rawMap['id']?.toString() ?? '';
        final port = HardwareMappingService().getPortForAppliance(id);
        _appliances.add(
          ApplianceModel.fromMap(rawMap, hardwarePort: port),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching appliances: $e');
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ApplianceModel> addAppliance(
    ApplianceModel appliance, {
    String? assignedPort,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception('User is not logged in');
      }

      final applianceWithUser = appliance.copyWith(
        userId: user.id,
      );

      final payload = applianceWithUser.toMap();

      final response = await _supabase
          .from('appliances')
          .insert(payload)
          .select()
          .single();

      final id = response['id']?.toString() ?? '';
      final port = assignedPort ?? appliance.hardwarePort;

      if (port != null && port.isNotEmpty && port != 'None') {
        await HardwareMappingService().bindApplianceToPort(id, port);
      }

      final savedAppliance = ApplianceModel.fromMap(
        Map<String, dynamic>.from(response),
        hardwarePort: port,
      );

      _appliances.insert(0, savedAppliance);
      return savedAppliance;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Error saving appliance: $e');
        debugPrintStack(stackTrace: stackTrace);
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Binds or reassigns a hardware port (e.g. COM3) to a specific appliance.
  Future<void> setApplianceHardwarePort(String applianceId, String? port) async {
    await HardwareMappingService().bindApplianceToPort(applianceId, port);

    // Refresh memory list
    for (int i = 0; i < _appliances.length; i++) {
      if (_appliances[i].id == applianceId) {
        _appliances[i] = _appliances[i].copyWith(hardwarePort: port);
      } else if (port != null && _appliances[i].hardwarePort == port) {
        // Unbind any other appliance previously holding this port
        _appliances[i] = _appliances[i].copyWith(hardwarePort: null);
      }
    }
    notifyListeners();
  }

  ApplianceModel? getApplianceById(String id) {
    try {
      return _appliances.firstWhere(
        (item) => item.id == id,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> removeAppliance(String id) async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception('User is not logged in');
      }

      await HardwareMappingService().unbindAppliance(id);

      await _supabase
          .from('appliances')
          .delete()
          .eq('id', id)
          .eq('user_id', user.id);

      _appliances.removeWhere(
        (item) => item.id == id,
      );

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error removing appliance: $e');
      }
      rethrow;
    }
  }

  void clear() {
    _appliances.clear();
    notifyListeners();
  }
}
