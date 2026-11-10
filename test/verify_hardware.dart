import 'dart:convert';
import 'package:myappliance/models/hardware_telemetry_model.dart';

void main() {
  print('=== Running Hardware Telemetry Model Verification ===');

  final jsonString = '''
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

  assert(telemetry.packetNumber == 42, 'Packet number should be 42');
  assert(telemetry.timeMs == 12500, 'Time ms should be 12500');
  assert(telemetry.relayOn == true, 'Relay should be ON');
  assert(telemetry.temperature == 27.9, 'Temperature should be 27.9');
  assert(telemetry.dsConnected == true, 'DS18B20 should be connected');
  assert(telemetry.mpuConnected == true, 'MPU6050 should be connected');
  assert(telemetry.micConnected == true, 'INMP441 should be connected');
  assert(telemetry.vibrationMagnitude >= 0.10 && telemetry.vibrationMagnitude <= 1.0, 'Vibration magnitude check');
  assert(telemetry.soundDb >= 30.0 && telemetry.soundDb <= 95.0, 'Sound dB check');

  print('JSON parsing & calculations: PASSED');

  // Test readable mode fallback
  const readableText = '''
MPU6050
Accel : X 0.1234 | Y -0.2345 | Z 9.8100
Gyro : X 0.0100 | Y -0.0200 | Z 0.0050

DS18B20
Temperature : 28.50 C

INMP441
RMS : 48.00
----------------------------------------
''';

  final readableTelemetry = HardwareTelemetryModel.fromReadableText(readableText);
  assert(readableTelemetry.temperature == 28.5, 'Readable temperature should be 28.5');
  assert(readableTelemetry.dsConnected == true, 'DS18B20 should be marked true');
  assert(readableTelemetry.mpuConnected == true, 'MPU6050 should be marked true');
  assert(readableTelemetry.micConnected == true, 'INMP441 should be marked true');

  print('Readable text parsing & calculations: PASSED');

  // Test Simulation Mode generator
  final simulated = HardwareTelemetryModel.simulated(
    relayOn: true,
    baseTemp: 35.0,
    baseVib: 0.25,
    baseSound: 50.0,
  );
  assert(simulated.relayOn == true, 'Simulated relay should be ON');
  assert(simulated.temperature >= 20.0 && simulated.temperature <= 60.0, 'Simulated temp within bounds');
  assert(simulated.soundDb >= 35.0 && simulated.soundDb <= 75.0, 'Simulated sound within bounds');
  assert(simulated.vibrationMagnitude >= 0.15 && simulated.vibrationMagnitude <= 0.45, 'Simulated vib within bounds');

  print('Simulation mode generator: PASSED');
  print('=== ALL TESTS PASSED SUCCESSFULLY! ===');
}

