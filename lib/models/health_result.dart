/// Result model holding calculated score, status, detected concerns, and recommendations.
class HealthResult {
  final int score;
  final String status; // 'HEALTHY', 'WARNING', 'CRITICAL'
  final List<String> issues;
  final List<String> recommendations;
  final DateTime createdAt;
  final String applianceId;
  final String applianceName;
  final String applianceType;
  final Map<String, String> answers;

  const HealthResult({
    required this.score,
    required this.status,
    required this.issues,
    required this.recommendations,
    required this.createdAt,
    required this.applianceId,
    required this.applianceName,
    required this.applianceType,
    required this.answers,
  });
}
