import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:myappliance/models/hardware_telemetry_model.dart';
import 'package:myappliance/models/sensor_reading_model.dart';
import 'package:myappliance/models/appliance_model.dart';
import 'package:myappliance/models/appliance_alert_model.dart';
import 'package:myappliance/services/sensor_analytics_service.dart';
import 'package:myappliance/services/alert_service.dart';

void main() {
  group('Hardware Telemetry & Analytics Verification', () {
    test('1. JSON parsing & calculations', () {
      const jsonString = '''
      {
        "type": "sensor_data",
        "packet": 42,
        "time_ms": 12500,
        "mpu6050": {
          "connected": true,
          "ax": 0.0521,
          "ay": -0.0134,
          "az": 9.8142,
          "gx": 0.0012,
          "gy": -0.0021,
          "gz": 0.0005,
          "temperature": 29.4
        },
        "ds18b20": {
          "connected": true,
          "temperature": 27.85
        },
        "inmp441": {
          "connected": true,
          "rms": 52.3,
          "peak": 1420
        },
        "relay": {
          "state": "ON"
        },
        "streaming": true
      }
      ''';

      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      final telemetry = HardwareTelemetryModel.fromJson(map);

      expect(telemetry.packetNumber, equals(42));
      expect(telemetry.timeMs, equals(12500));
      expect(telemetry.relayOn, isTrue);
      expect(telemetry.temperature, equals(27.9));
      expect(telemetry.dsConnected, isTrue);
      expect(telemetry.mpuConnected, isTrue);
      expect(telemetry.micConnected, isTrue);
      expect(telemetry.vibrationMagnitude >= 0.10 && telemetry.vibrationMagnitude <= 1.0, isTrue);
      expect(telemetry.soundDb >= 30.0 && telemetry.soundDb <= 95.0, isTrue);
    });

    test('2. Readable text mode fallback', () {
      const readableText = '''
Accel : X 0.02 | Y 0.01 | Z 9.81
Gyro : X 0.00 | Y 0.00 | Z 0.00
Temperature : 28.50 C
RMS : 45.00
''';

      final telemetry = HardwareTelemetryModel.fromReadableText(readableText);
      expect(telemetry.packetNumber, equals(0));
      expect(telemetry.temperature, equals(28.5));
      expect(telemetry.dsConnected, isTrue);
      expect(telemetry.mpuConnected, isTrue);
      expect(telemetry.micConnected, isTrue);
      expect(telemetry.soundDb > 30.0, isTrue);
      expect(telemetry.vibrationMagnitude > 0.0, isTrue);
    });

    test('3. Analytics Service calculations', () {
      final now = DateTime.now();
      final sampleReadings = [
        SensorReadingModel(
          id: '1',
          applianceId: 'app-1',
          applianceName: 'Test Refrigerator',
          temperature: 30.0,
          vibration: 0.15,
          sound: 40.0,
          recordedAt: now.subtract(const Duration(minutes: 30)),
        ),
        SensorReadingModel(
          id: '2',
          applianceId: 'app-1',
          applianceName: 'Test Refrigerator',
          temperature: 32.0,
          vibration: 0.20,
          sound: 42.0,
          recordedAt: now.subtract(const Duration(minutes: 15)),
        ),
        SensorReadingModel(
          id: '3',
          applianceId: 'app-1',
          applianceName: 'Test Refrigerator',
          temperature: 35.0,
          vibration: 0.25,
          sound: 48.0,
          recordedAt: now,
        ),
      ];

      final summary = SensorAnalyticsService.computeAnalytics(sampleReadings);
      expect(summary.totalReadings, equals(3));
      expect(summary.temperature.min, equals(30.0));
      expect(summary.temperature.max, equals(35.0));
      expect(summary.temperature.average > 32.0, isTrue);
      expect(summary.temperature.latest, equals(35.0));
      expect(summary.vibration.latest, equals(0.25));
      expect(summary.sound.latest, equals(48.0));
    });

    test('4. Alert Service thresholds & evaluations', () {
      final alertService = AlertService();
      alertService.clear();

      final now = DateTime.now();
      final testAppliance = ApplianceModel(
        id: 'app-1',
        userId: 'user-1',
        name: 'Living Room AC',
        type: 'Air Conditioner',
        addedAt: now,
      );

      // Normal reading -> No alerts
      alertService.evaluateReadings(testAppliance, [
        SensorReadingModel(
          id: 'r1',
          applianceId: 'app-1',
          applianceName: 'Living Room AC',
          temperature: 25.0,
          vibration: 0.20,
          sound: 45.0,
          recordedAt: now,
        ),
      ]);
      expect(alertService.allAlerts.isEmpty, isTrue);

      // Warning reading (>55°C temp) -> Should trigger temperature warning
      alertService.evaluateReadings(testAppliance, [
        SensorReadingModel(
          id: 'r2',
          applianceId: 'app-1',
          applianceName: 'Living Room AC',
          temperature: 58.5,
          vibration: 0.20,
          sound: 45.0,
          recordedAt: now,
        ),
      ]);
      expect(alertService.allAlerts.isNotEmpty, isTrue);
      expect(alertService.allAlerts.first.severity, equals(AlertSeverity.warning));
      expect(alertService.allAlerts.first.parameter, equals(AlertParameter.temperature));
    });

    test('5. Simulation mode generator', () {
      final simulated = HardwareTelemetryModel.simulated(
        relayOn: true,
        baseTemp: 35.0,
        baseVib: 0.25,
        baseSound: 50.0,
      );
      expect(simulated.relayOn, isTrue);
      expect(simulated.temperature >= 20.0 && simulated.temperature <= 60.0, isTrue);
    });

    test('6. Predictive Failure Analysis calculations', () {
      final now = DateTime.now();

      // Normal healthy dataset
      final healthyReadings = [
        SensorReadingModel(
          id: 'h1',
          applianceId: 'app-1',
          applianceName: 'Test Refrigerator',
          temperature: 28.0,
          vibration: 0.16,
          sound: 42.0,
          recordedAt: now.subtract(const Duration(minutes: 10)),
        ),
        SensorReadingModel(
          id: 'h2',
          applianceId: 'app-1',
          applianceName: 'Test Refrigerator',
          temperature: 29.0,
          vibration: 0.18,
          sound: 44.0,
          recordedAt: now,
        ),
      ];

      final healthyPred = SensorAnalyticsService.computePredictiveFailure(healthyReadings);
      expect(healthyPred.riskLevel, equals(FailureRiskLevel.low));
      expect(healthyPred.failureRiskPercent < 25.0, isTrue);
      expect(healthyPred.estimatedDaysToFailure >= 90, isTrue);

      // High mechanical & thermal stress dataset
      final stressedReadings = [
        SensorReadingModel(
          id: 's1',
          applianceId: 'app-1',
          applianceName: 'Test Refrigerator',
          temperature: 68.0,
          vibration: 0.75,
          sound: 78.0,
          recordedAt: now.subtract(const Duration(minutes: 5)),
        ),
        SensorReadingModel(
          id: 's2',
          applianceId: 'app-1',
          applianceName: 'Test Refrigerator',
          temperature: 72.0,
          vibration: 0.85,
          sound: 80.0,
          recordedAt: now,
        ),
      ];

      final stressedPred = SensorAnalyticsService.computePredictiveFailure(stressedReadings);
      expect(stressedPred.riskLevel == FailureRiskLevel.high || stressedPred.riskLevel == FailureRiskLevel.critical, isTrue);
      expect(stressedPred.failureRiskPercent >= 60.0, isTrue);
      expect(stressedPred.estimatedDaysToFailure <= 28, isTrue);
      expect(stressedPred.preventativeRecommendations.isNotEmpty, isTrue);
      expect(stressedPred.riskProgressionCurve.length, equals(2));
    });
  });
}
