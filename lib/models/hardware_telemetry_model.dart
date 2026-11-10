import 'dart:math';

/// Live sensor telemetry received from the ESP32 / Arduino hardware.
/// Contains parsed readings for MPU6050, DS18B20, INMP441, and Relay state.
class HardwareTelemetryModel {
  final int packetNumber;
  final int timeMs;
  final DateTime receivedAt;

  // Temperature (°C)
  final double temperature;
  final bool dsConnected;
  final double? dsTemperature;
  final double? mpuTemperature;

  // Vibration & IMU (MPU6050)
  final bool mpuConnected;
  final double ax;
  final double ay;
  final double az;
  final double gx;
  final double gy;
  final double gz;
  final double vibrationMagnitude; // Normalized ~0.10 to 1.00

  // Sound / Acoustic (INMP441)
  final bool micConnected;
  final double micRms;
  final int micPeak;
  final double soundDb; // Normalized 30.0 to 90.0+ dB

  // Relay & State
  final bool relayOn;
  final bool isStreaming;
  final String rawJson;

  const HardwareTelemetryModel({
    required this.packetNumber,
    required this.timeMs,
    required this.receivedAt,
    required this.temperature,
    required this.dsConnected,
    this.dsTemperature,
    this.mpuTemperature,
    required this.mpuConnected,
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
    required this.vibrationMagnitude,
    required this.micConnected,
    required this.micRms,
    required this.micPeak,
    required this.soundDb,
    required this.relayOn,
    required this.isStreaming,
    this.rawJson = '',
  });

  /// Factory to parse from the Arduino JSON mode output:
  /// {
  ///   "type":"sensor_data",
  ///   "packet":0,
  ///   "time_ms":1000,
  ///   "mpu6050":{"connected":true,"ax":0.1,"ay":0.2,"az":9.8,"gx":0,"gy":0,"gz":0,"temperature":28.0},
  ///   "ds18b20":{"connected":true,"temperature":26.5},
  ///   "inmp441":{"connected":true,"rms":45.0,"peak":1200},
  ///   "relay":{"state":"OFF"},
  ///   "streaming":true
  /// }
  factory HardwareTelemetryModel.fromJson(Map<String, dynamic> json) {
    final mpu = json['mpu6050'] is Map ? Map<String, dynamic>.from(json['mpu6050']) : {};
    final ds = json['ds18b20'] is Map ? Map<String, dynamic>.from(json['ds18b20']) : {};
    final mic = json['inmp441'] is Map ? Map<String, dynamic>.from(json['inmp441']) : {};
    final relay = json['relay'] is Map ? Map<String, dynamic>.from(json['relay']) : {};

    final mpuOk = mpu['connected'] == true;
    final ax = _toDouble(mpu['ax']);
    final ay = _toDouble(mpu['ay']);
    final az = _toDouble(mpu['az']);
    final gx = _toDouble(mpu['gx']);
    final gy = _toDouble(mpu['gy']);
    final gz = _toDouble(mpu['gz']);
    final mpuTemp = mpu['temperature'] != null ? _toDouble(mpu['temperature']) : null;

    // Vibration calculation:
    // Magnitude of total acceleration vector minus Earth gravity (approx 9.806 m/s^2),
    // normalized to dynamic Gs (0.15 - 0.90)
    final totalAcc = sqrt(ax * ax + ay * ay + az * az);
    double calculatedVibration;
    if (mpuOk) {
      final dynamicDelta = (totalAcc - 9.80665).abs();
      // Normalize: small motion 0.15 - 0.35, active 0.40 - 0.80
      calculatedVibration = double.parse((0.15 + (dynamicDelta / 9.80665) * 0.85).clamp(0.05, 2.50).toStringAsFixed(2));
    } else {
      calculatedVibration = 0.20;
    }

    final dsOk = ds['connected'] == true;
    final dsTemp = ds['temperature'] != null ? _toDouble(ds['temperature']) : null;

    // Use DS18B20 temperature if available, else MPU6050 temperature, else 25.0
    double finalTemp;
    if (dsOk && dsTemp != null && dsTemp > -50 && dsTemp < 150) {
      finalTemp = dsTemp;
    } else if (mpuTemp != null && mpuTemp > -40 && mpuTemp < 120) {
      finalTemp = mpuTemp;
    } else {
      finalTemp = 25.0;
    }

    final micOk = mic['connected'] == true;
    final rms = _toDouble(mic['rms']);
    final peak = mic['peak'] is num ? (mic['peak'] as num).toInt() : 0;

    // Sound calculation:
    // RMS from INMP441 typically spans 10 to 5000+
    // Convert to decibels (approx 35 - 85 dB SPL scale)
    double calculatedSound;
    if (micOk && rms > 0) {
      // dB = 20 * log10(rms) with baseline scaling
      final logVal = 20.0 * (log(rms + 1.0) / ln10);
      calculatedSound = double.parse((32.0 + logVal * 0.8).clamp(30.0, 95.0).toStringAsFixed(1));
    } else {
      calculatedSound = 42.0;
    }

    final relayStateStr = relay['state']?.toString().toUpperCase() ?? 'OFF';
    final relayIsOn = relayStateStr == 'ON';

    return HardwareTelemetryModel(
      packetNumber: json['packet'] is num ? (json['packet'] as num).toInt() : 0,
      timeMs: json['time_ms'] is num ? (json['time_ms'] as num).toInt() : 0,
      receivedAt: DateTime.now(),
      temperature: double.parse(finalTemp.toStringAsFixed(1)),
      dsConnected: dsOk,
      dsTemperature: dsTemp,
      mpuTemperature: mpuTemp,
      mpuConnected: mpuOk,
      ax: ax,
      ay: ay,
      az: az,
      gx: gx,
      gy: gy,
      gz: gz,
      vibrationMagnitude: calculatedVibration,
      micConnected: micOk,
      micRms: rms,
      micPeak: peak,
      soundDb: calculatedSound,
      relayOn: relayIsOn,
      isStreaming: json['streaming'] != false,
      rawJson: json.toString(),
    );
  }

  /// Fallback parser for Arduino readable text mode output
  factory HardwareTelemetryModel.fromReadableText(String text) {
    double ax = 0, ay = 0, az = 9.8;
    double gx = 0, gy = 0, gz = 0;
    double temp = 25.0;
    double rms = 40.0;
    bool mpuOk = false;
    bool dsOk = false;
    bool micOk = false;

    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('Accel :')) {
        mpuOk = true;
        final xMatch = RegExp(r'X\s+([-\d.]+)').firstMatch(trimmed);
        final yMatch = RegExp(r'Y\s+([-\d.]+)').firstMatch(trimmed);
        final zMatch = RegExp(r'Z\s+([-\d.]+)').firstMatch(trimmed);
        if (xMatch != null) ax = double.tryParse(xMatch.group(1)!) ?? 0;
        if (yMatch != null) ay = double.tryParse(yMatch.group(1)!) ?? 0;
        if (zMatch != null) az = double.tryParse(zMatch.group(1)!) ?? 9.8;
      } else if (trimmed.startsWith('Gyro :')) {
        final xMatch = RegExp(r'X\s+([-\d.]+)').firstMatch(trimmed);
        final yMatch = RegExp(r'Y\s+([-\d.]+)').firstMatch(trimmed);
        final zMatch = RegExp(r'Z\s+([-\d.]+)').firstMatch(trimmed);
        if (xMatch != null) gx = double.tryParse(xMatch.group(1)!) ?? 0;
        if (yMatch != null) gy = double.tryParse(yMatch.group(1)!) ?? 0;
        if (zMatch != null) gz = double.tryParse(zMatch.group(1)!) ?? 0;
      } else if (trimmed.startsWith('Temperature :')) {
        dsOk = true;
        final tMatch = RegExp(r'Temperature\s*:\s*([-\d.]+)').firstMatch(trimmed);
        if (tMatch != null) temp = double.tryParse(tMatch.group(1)!) ?? 25.0;
      } else if (trimmed.startsWith('RMS :')) {
        micOk = true;
        final rMatch = RegExp(r'RMS\s*:\s*([-\d.]+)').firstMatch(trimmed);
        if (rMatch != null) rms = double.tryParse(rMatch.group(1)!) ?? 40.0;
      }
    }

    final totalAcc = sqrt(ax * ax + ay * ay + az * az);
    final vib = double.parse((0.15 + ((totalAcc - 9.8).abs() / 9.8) * 0.85).clamp(0.05, 2.50).toStringAsFixed(2));
    final sound = double.parse((32.0 + 20.0 * (log(rms + 1.0) / ln10) * 0.8).clamp(30.0, 95.0).toStringAsFixed(1));

    return HardwareTelemetryModel(
      packetNumber: 0,
      timeMs: DateTime.now().millisecondsSinceEpoch,
      receivedAt: DateTime.now(),
      temperature: temp,
      dsConnected: dsOk,
      dsTemperature: temp,
      mpuTemperature: temp,
      mpuConnected: mpuOk,
      ax: ax,
      ay: ay,
      az: az,
      gx: gx,
      gy: gy,
      gz: gz,
      vibrationMagnitude: vib,
      micConnected: micOk,
      micRms: rms,
      micPeak: (rms * 2).toInt(),
      soundDb: sound,
      relayOn: false,
      isStreaming: true,
      rawJson: text,
    );
  }

  /// Generates a realistic simulated telemetry packet for demonstration or testing when COM3 is disconnected
  factory HardwareTelemetryModel.simulated({
    required bool relayOn,
    required double baseTemp,
    required double baseVib,
    required double baseSound,
  }) {
    final rand = Random();
    final tempJitter = (rand.nextDouble() - 0.5) * 1.2;
    final vibJitter = (rand.nextDouble() - 0.5) * 0.08;
    final soundJitter = (rand.nextDouble() - 0.5) * 4.0;

    final finalTemp = double.parse((baseTemp + tempJitter).clamp(10.0, 85.0).toStringAsFixed(1));
    final finalVib = double.parse((baseVib + vibJitter).clamp(0.08, 1.50).toStringAsFixed(2));
    final finalSound = double.parse((baseSound + soundJitter).clamp(32.0, 95.0).toStringAsFixed(1));

    return HardwareTelemetryModel(
      packetNumber: rand.nextInt(10000),
      timeMs: DateTime.now().millisecondsSinceEpoch,
      receivedAt: DateTime.now(),
      temperature: finalTemp,
      dsConnected: true,
      dsTemperature: finalTemp,
      mpuTemperature: finalTemp + 1.2,
      mpuConnected: true,
      ax: double.parse(((rand.nextDouble() - 0.5) * 0.4).toStringAsFixed(4)),
      ay: double.parse(((rand.nextDouble() - 0.5) * 0.4).toStringAsFixed(4)),
      az: double.parse((9.80 + (rand.nextDouble() - 0.5) * 0.3).toStringAsFixed(4)),
      gx: double.parse(((rand.nextDouble() - 0.5) * 0.02).toStringAsFixed(4)),
      gy: double.parse(((rand.nextDouble() - 0.5) * 0.02).toStringAsFixed(4)),
      gz: double.parse(((rand.nextDouble() - 0.5) * 0.02).toStringAsFixed(4)),
      vibrationMagnitude: finalVib,
      micConnected: true,
      micRms: finalSound * 1.5,
      micPeak: (finalSound * 25).toInt(),
      soundDb: finalSound,
      relayOn: relayOn,
      isStreaming: true,
      rawJson: 'SIMULATED',
    );
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }
}

