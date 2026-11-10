/// Data model representing a single telemetry reading from public.sensor_readings.
class SensorReadingModel {
  final String id;
  final String applianceId;
  final String applianceName;
  final double temperature;
  final double vibration;
  final double sound;
  final DateTime recordedAt;

  const SensorReadingModel({
    required this.id,
    required this.applianceId,
    required this.applianceName,
    required this.temperature,
    required this.vibration,
    required this.sound,
    required this.recordedAt,
  });

  factory SensorReadingModel.fromMap(Map<String, dynamic> map) {
    return SensorReadingModel(
      id: map['id']?.toString() ?? '',
      applianceId: map['appliance_id']?.toString() ?? '',
      applianceName: map['appliance_name']?.toString() ?? '',
      temperature: _parseDouble(map['temperature']),
      vibration: _parseDouble(map['vibration']),
      sound: _parseDouble(map['sound']),
      recordedAt: map['recorded_at'] != null
          ? DateTime.tryParse(map['recorded_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'appliance_id': applianceId,
      'appliance_name': applianceName,
      'temperature': temperature,
      'vibration': vibration,
      'sound': sound,
      'recorded_at': recordedAt.toIso8601String(),
    };
  }
}
