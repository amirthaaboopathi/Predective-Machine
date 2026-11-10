enum AlertSeverity {
  normal,
  warning,
  critical,
  offline,
}

enum AlertParameter {
  temperature,
  vibration,
  sound,
  connectivity,
  general,
}

/// Represents an operational alert or notification for an appliance.
class ApplianceAlertModel {
  final String id;
  final String applianceId;
  final String applianceName;
  final String title;
  final String description;
  final AlertParameter parameter;
  final AlertSeverity severity;
  final double? recordedValue;
  final String? unit;
  final DateTime timestamp;
  final bool isAcknowledged;

  const ApplianceAlertModel({
    required this.id,
    required this.applianceId,
    required this.applianceName,
    required this.title,
    required this.description,
    required this.parameter,
    required this.severity,
    this.recordedValue,
    this.unit,
    required this.timestamp,
    this.isAcknowledged = false,
  });

  ApplianceAlertModel copyWith({
    String? id,
    String? applianceId,
    String? applianceName,
    String? title,
    String? description,
    AlertParameter? parameter,
    AlertSeverity? severity,
    double? recordedValue,
    String? unit,
    DateTime? timestamp,
    bool? isAcknowledged,
  }) {
    return ApplianceAlertModel(
      id: id ?? this.id,
      applianceId: applianceId ?? this.applianceId,
      applianceName: applianceName ?? this.applianceName,
      title: title ?? this.title,
      description: description ?? this.description,
      parameter: parameter ?? this.parameter,
      severity: severity ?? this.severity,
      recordedValue: recordedValue ?? this.recordedValue,
      unit: unit ?? this.unit,
      timestamp: timestamp ?? this.timestamp,
      isAcknowledged: isAcknowledged ?? this.isAcknowledged,
    );
  }
}
