import 'package:flutter/foundation.dart';
import '../models/appliance_alert_model.dart';
import '../models/sensor_reading_model.dart';
import '../models/appliance_model.dart';
import 'hardware_serial_service.dart';

/// Manages and derives verified operational alerts based strictly on real sensor data.
class AlertService extends ChangeNotifier {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal();

  final List<ApplianceAlertModel> _alerts = [];
  final Set<String> _acknowledgedAlertIds = {};

  List<ApplianceAlertModel> get allAlerts => List.unmodifiable(_alerts);

  int get unreadWarningCount => _alerts
      .where((a) => !a.isAcknowledged && a.severity != AlertSeverity.normal)
      .length;

  /// Evaluates real sensor readings for an appliance and produces real condition alerts.
  void evaluateReadings(ApplianceModel appliance, List<SensorReadingModel> readings) {
    if (readings.isEmpty) return;

    final latest = readings.first;
    _evaluateSingleReading(appliance, latest);
  }

  /// Evaluates live telemetry from the monitoring device.
  void evaluateLiveTelemetry(ApplianceModel appliance) {
    final hardwareService = HardwareSerialService();
    final telemetry = hardwareService.latestTelemetry;
    if (telemetry == null) return;

    final reading = SensorReadingModel(
      id: 'live-${DateTime.now().millisecondsSinceEpoch}',
      applianceId: appliance.id,
      applianceName: appliance.name,
      temperature: telemetry.temperature,
      vibration: telemetry.vibrationMagnitude,
      sound: telemetry.soundDb,
      recordedAt: telemetry.receivedAt,
    );

    _evaluateSingleReading(appliance, reading);
  }

  void _evaluateSingleReading(ApplianceModel appliance, SensorReadingModel reading) {
    final List<ApplianceAlertModel> newAlerts = [];

    // 1. Temperature Evaluation
    if (reading.temperature > 70.0) {
      newAlerts.add(ApplianceAlertModel(
        id: 'temp-crit-${reading.recordedAt.millisecondsSinceEpoch}',
        applianceId: appliance.id,
        applianceName: appliance.name,
        title: 'Critical Temperature Alert',
        description: 'Appliance temperature reached ${reading.temperature}°C, exceeding the safe limit of 70°C.',
        parameter: AlertParameter.temperature,
        severity: AlertSeverity.critical,
        recordedValue: reading.temperature,
        unit: '°C',
        timestamp: reading.recordedAt,
        isAcknowledged: _acknowledgedAlertIds.contains('temp-crit-${reading.recordedAt.millisecondsSinceEpoch}'),
      ));
    } else if (reading.temperature > 55.0) {
      newAlerts.add(ApplianceAlertModel(
        id: 'temp-warn-${reading.recordedAt.millisecondsSinceEpoch}',
        applianceId: appliance.id,
        applianceName: appliance.name,
        title: 'Elevated Temperature Warning',
        description: 'Appliance temperature is ${reading.temperature}°C, which is above the optimal operating range (20°C - 55°C).',
        parameter: AlertParameter.temperature,
        severity: AlertSeverity.warning,
        recordedValue: reading.temperature,
        unit: '°C',
        timestamp: reading.recordedAt,
        isAcknowledged: _acknowledgedAlertIds.contains('temp-warn-${reading.recordedAt.millisecondsSinceEpoch}'),
      ));
    }

    // 2. Vibration Evaluation
    if (reading.vibration > 0.80) {
      newAlerts.add(ApplianceAlertModel(
        id: 'vib-crit-${reading.recordedAt.millisecondsSinceEpoch}',
        applianceId: appliance.id,
        applianceName: appliance.name,
        title: 'High Mechanical Vibration',
        description: 'Vibration reached ${reading.vibration} G. Please verify that the appliance is level and mechanically stable.',
        parameter: AlertParameter.vibration,
        severity: AlertSeverity.critical,
        recordedValue: reading.vibration,
        unit: 'G',
        timestamp: reading.recordedAt,
        isAcknowledged: _acknowledgedAlertIds.contains('vib-crit-${reading.recordedAt.millisecondsSinceEpoch}'),
      ));
    } else if (reading.vibration > 0.40) {
      newAlerts.add(ApplianceAlertModel(
        id: 'vib-warn-${reading.recordedAt.millisecondsSinceEpoch}',
        applianceId: appliance.id,
        applianceName: appliance.name,
        title: 'Elevated Vibration Level',
        description: 'Vibration is slightly elevated at ${reading.vibration} G (typical baseline: 0.10 - 0.40 G).',
        parameter: AlertParameter.vibration,
        severity: AlertSeverity.warning,
        recordedValue: reading.vibration,
        unit: 'G',
        timestamp: reading.recordedAt,
        isAcknowledged: _acknowledgedAlertIds.contains('vib-warn-${reading.recordedAt.millisecondsSinceEpoch}'),
      ));
    }

    // 3. Sound Evaluation
    if (reading.sound > 75.0) {
      newAlerts.add(ApplianceAlertModel(
        id: 'sound-crit-${reading.recordedAt.millisecondsSinceEpoch}',
        applianceId: appliance.id,
        applianceName: appliance.name,
        title: 'Excessive Operating Sound',
        description: 'Acoustic sound level spiked to ${reading.sound.round()} dB, exceeding the 75 dB threshold.',
        parameter: AlertParameter.sound,
        severity: AlertSeverity.critical,
        recordedValue: reading.sound,
        unit: 'dB',
        timestamp: reading.recordedAt,
        isAcknowledged: _acknowledgedAlertIds.contains('sound-crit-${reading.recordedAt.millisecondsSinceEpoch}'),
      ));
    } else if (reading.sound > 62.0) {
      newAlerts.add(ApplianceAlertModel(
        id: 'sound-warn-${reading.recordedAt.millisecondsSinceEpoch}',
        applianceId: appliance.id,
        applianceName: appliance.name,
        title: 'Elevated Noise Level',
        description: 'Operating sound is ${reading.sound.round()} dB, which is higher than the normal background range (30 - 60 dB).',
        parameter: AlertParameter.sound,
        severity: AlertSeverity.warning,
        recordedValue: reading.sound,
        unit: 'dB',
        timestamp: reading.recordedAt,
        isAcknowledged: _acknowledgedAlertIds.contains('sound-warn-${reading.recordedAt.millisecondsSinceEpoch}'),
      ));
    }

    // Add unique alerts without duplicates
    for (final a in newAlerts) {
      if (!_alerts.any((existing) => existing.id == a.id)) {
        _alerts.insert(0, a);
      }
    }

    // Keep alert list manageable (latest 100)
    if (_alerts.length > 100) {
      _alerts.removeRange(100, _alerts.length);
    }

    notifyListeners();
  }

  /// Marks an alert as acknowledged by user.
  void acknowledgeAlert(String id) {
    _acknowledgedAlertIds.add(id);
    final index = _alerts.indexWhere((a) => a.id == id);
    if (index != -1) {
      _alerts[index] = _alerts[index].copyWith(isAcknowledged: true);
      notifyListeners();
    }
  }

  /// Marks all current alerts as acknowledged.
  void acknowledgeAll() {
    for (int i = 0; i < _alerts.length; i++) {
      _acknowledgedAlertIds.add(_alerts[i].id);
      _alerts[i] = _alerts[i].copyWith(isAcknowledged: true);
    }
    notifyListeners();
  }

  /// Clears alert list.
  void clear() {
    _alerts.clear();
    _acknowledgedAlertIds.clear();
    notifyListeners();
  }
}
