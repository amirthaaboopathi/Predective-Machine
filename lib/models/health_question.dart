import 'health_option.dart';

/// Question model representing an appliance-type specific diagnostic prompt.
class HealthQuestion {
  final String id;
  final String applianceType;
  final String question;
  final List<HealthOption> options;

  const HealthQuestion({
    required this.id,
    required this.applianceType,
    required this.question,
    required this.options,
  });
}
