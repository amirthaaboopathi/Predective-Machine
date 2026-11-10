/// Option model for an appliance health check question.
class HealthOption {
  final String id;
  final String label;
  final int riskScore;
  final String? issueDescription;
  final String? recommendation;

  const HealthOption({
    required this.id,
    required this.label,
    required this.riskScore,
    this.issueDescription,
    this.recommendation,
  });
}
