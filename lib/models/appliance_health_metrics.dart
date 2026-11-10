import 'sensor_reading_model.dart';

/// Data model representing calculated average sensor metrics and normalized health scores.
class ApplianceHealthMetrics {
  final double averageTemperature;
  final double averageVibration;
  final double averageSound;
  final double temperatureHealth;
  final double vibrationHealth;
  final double soundHealth;
  final double? overallHealthScore;
  final String healthStatus; // 'Good', 'Average', 'Poor', 'No Data'
  final int readingCount;

  const ApplianceHealthMetrics({
    required this.averageTemperature,
    required this.averageVibration,
    required this.averageSound,
    required this.temperatureHealth,
    required this.vibrationHealth,
    required this.soundHealth,
    required this.overallHealthScore,
    required this.healthStatus,
    required this.readingCount,
  });

  factory ApplianceHealthMetrics.fromReadings(List<SensorReadingModel> readings) {
    if (readings.isEmpty) {
      return const ApplianceHealthMetrics(
        averageTemperature: 0.0,
        averageVibration: 0.0,
        averageSound: 0.0,
        temperatureHealth: 0.0,
        vibrationHealth: 0.0,
        soundHealth: 0.0,
        overallHealthScore: null,
        healthStatus: 'No Data',
        readingCount: 0,
      );
    }

    final totalTemp = readings.map((r) => r.temperature).reduce((a, b) => a + b);
    final totalVib = readings.map((r) => r.vibration).reduce((a, b) => a + b);
    final totalSound = readings.map((r) => r.sound).reduce((a, b) => a + b);

    final count = readings.length;
    final avgTemp = totalTemp / count;
    final avgVib = totalVib / count;
    final avgSound = totalSound / count;

    final tempHealth = calculateTemperatureHealth(avgTemp);
    final vibHealth = calculateVibrationHealth(avgVib);
    final soundHealth = calculateSoundHealth(avgSound);

    final overall = (tempHealth + vibHealth + soundHealth) / 3.0;

    String status;
    if (overall >= 80.0) {
      status = 'Good';
    } else if (overall >= 60.0) {
      status = 'Average';
    } else {
      status = 'Poor';
    }

    return ApplianceHealthMetrics(
      averageTemperature: double.parse(avgTemp.toStringAsFixed(1)),
      averageVibration: double.parse(avgVib.toStringAsFixed(2)),
      averageSound: double.parse(avgSound.toStringAsFixed(1)),
      temperatureHealth: double.parse(tempHealth.toStringAsFixed(1)),
      vibrationHealth: double.parse(vibHealth.toStringAsFixed(1)),
      soundHealth: double.parse(soundHealth.toStringAsFixed(1)),
      overallHealthScore: double.parse(overall.toStringAsFixed(2)),
      healthStatus: status,
      readingCount: count,
    );
  }

  /// Temperature threshold model:
  /// 20–60°C → 100
  /// 60–80°C → gradually decrease from 100 to 0
  /// > 80°C  → 0
  /// < 20°C  → gradually decrease from 100 to 0
  static double calculateTemperatureHealth(double temp) {
    if (temp >= 20.0 && temp <= 60.0) {
      return 100.0;
    } else if (temp > 60.0 && temp <= 80.0) {
      return (100.0 - ((temp - 60.0) / 20.0) * 100.0).clamp(0.0, 100.0);
    } else if (temp > 80.0) {
      return 0.0;
    } else {
      return (100.0 - ((20.0 - temp) / 20.0) * 100.0).clamp(0.0, 100.0);
    }
  }

  /// Vibration threshold model:
  /// 0.10–0.40 → 100
  /// 0.40–1.00 → gradually decrease from 100 to 0
  /// > 1.00    → 0
  static double calculateVibrationHealth(double vib) {
    if (vib <= 0.40) {
      return 100.0;
    } else if (vib > 0.40 && vib <= 1.00) {
      return (100.0 - ((vib - 0.40) / 0.60) * 100.0).clamp(0.0, 100.0);
    } else {
      return 0.0;
    }
  }

  /// Sound threshold model:
  /// 30–60 dB → 100
  /// 60–90 dB → gradually decrease from 100 to 0
  /// > 90 dB  → 0
  static double calculateSoundHealth(double sound) {
    if (sound <= 60.0) {
      return 100.0;
    } else if (sound > 60.0 && sound <= 90.0) {
      return (100.0 - ((sound - 60.0) / 30.0) * 100.0).clamp(0.0, 100.0);
    } else {
      return 0.0;
    }
  }
}
