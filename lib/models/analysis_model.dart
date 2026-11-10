/// Model representing real analysis results returned from a diagnostic run.
class AnalysisModel {
  final String id;
  final String applianceId;
  final String applianceName;
  final String applianceType;
  final DateTime analyzedAt;
  final String healthCondition;
  final List<String> detectedIssues;
  final String recommendedAction;
  final Map<String, String> diagnosticDetails;

  const AnalysisModel({
    required this.id,
    required this.applianceId,
    required this.applianceName,
    required this.applianceType,
    required this.analyzedAt,
    required this.healthCondition,
    required this.detectedIssues,
    required this.recommendedAction,
    required this.diagnosticDetails,
  });
}
