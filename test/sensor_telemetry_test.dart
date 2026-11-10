import 'package:flutter_test/flutter_test.dart';
import 'package:myappliance/models/sensor_reading_model.dart';
import 'package:myappliance/models/appliance_health_metrics.dart';

void main() {
  group('Sensor Telemetry & Health Metrics Tests', () {
    test('Parses SensorReadingModel from Supabase JSON map accurately', () {
      final supabaseRow = {
        'id': 'sr-100',
        'appliance_id': 'app-123',
        'appliance_name': 'Samsung Refrigerator',
        'temperature': 38.5,
        'vibration': 0.22,
        'sound': 42.0,
        'recorded_at': '2026-10-12T10:00:00.000Z',
      };

      final reading = SensorReadingModel.fromMap(supabaseRow);
      expect(reading.id, 'sr-100');
      expect(reading.applianceId, 'app-123');
      expect(reading.applianceName, 'Samsung Refrigerator');
      expect(reading.temperature, 38.5);
      expect(reading.vibration, 0.22);
      expect(reading.sound, 42.0);
    });

    test('Computes aggregate telemetry averages across multiple readings', () {
      final readings = [
        SensorReadingModel(
          id: '1',
          applianceId: 'app-1',
          applianceName: 'Fridge',
          temperature: 30.0,
          vibration: 0.20,
          sound: 40.0,
          recordedAt: DateTime.now(),
        ),
        SensorReadingModel(
          id: '2',
          applianceId: 'app-1',
          applianceName: 'Fridge',
          temperature: 40.0,
          vibration: 0.30,
          sound: 50.0,
          recordedAt: DateTime.now(),
        ),
      ];

      final metrics = ApplianceHealthMetrics.fromReadings(readings);

      expect(metrics.readingCount, 2);
      expect(metrics.averageTemperature, 35.0);
      expect(metrics.averageVibration, 0.25);
      expect(metrics.averageSound, 45.0);
      expect(metrics.healthStatus, 'Good');
      expect(metrics.overallHealthScore, isNotNull);
      expect(metrics.overallHealthScore!, greaterThanOrEqualTo(80.0));
    });

    test('Handles empty readings gracefully with No Data status', () {
      final metrics = ApplianceHealthMetrics.fromReadings([]);

      expect(metrics.readingCount, 0);
      expect(metrics.averageTemperature, 0.0);
      expect(metrics.averageVibration, 0.0);
      expect(metrics.averageSound, 0.0);
      expect(metrics.healthStatus, 'No Data');
      expect(metrics.overallHealthScore, isNull);
    });
  });
}
