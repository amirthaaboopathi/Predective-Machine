import '../models/appliance_model.dart';
import '../models/health_question.dart';
import '../models/health_option.dart';
import '../models/health_result.dart';
import '../data/appliance_health_questions.dart';
import 'analysis_service.dart';
import '../models/analysis_model.dart';

/// Business logic engine for retrieving questions, calculating health scores,
/// detecting potential issues, and generating recommendations.
class HealthCheckService {
  static final HealthCheckService _instance = HealthCheckService._internal();
  factory HealthCheckService() => _instance;
  HealthCheckService._internal();

  /// Retrieves questions for a specific appliance type from the repository.
  List<HealthQuestion> getQuestionsForApplianceType(String applianceType) {
    if (applianceHealthQuestions.containsKey(applianceType)) {
      return applianceHealthQuestions[applianceType]!;
    }
    
    // Case-insensitive lookup fallback
    final key = applianceHealthQuestions.keys.firstWhere(
      (k) => k.toLowerCase() == applianceType.toLowerCase(),
      orElse: () => '',
    );

    if (key.isNotEmpty) {
      return applianceHealthQuestions[key]!;
    }

    return const [];
  }

  /// Calculates a normalized health score (0-100), status category, and actionable recommendations.
  HealthResult calculateHealthResult({
    required ApplianceModel appliance,
    required Map<String, HealthOption> userAnswers,
  }) {
    final questions = getQuestionsForApplianceType(appliance.type);

    int totalRisk = 0;
    int maxRisk = 0;

    for (final q in questions) {
      // Find maximum possible risk for this question
      final maxQuestionRisk = q.options.fold<int>(
        0,
        (maxVal, opt) => opt.riskScore > maxVal ? opt.riskScore : maxVal,
      );
      maxRisk += maxQuestionRisk;

      // Add selected option risk score
      final selectedOption = userAnswers[q.id];
      if (selectedOption != null) {
        totalRisk += selectedOption.riskScore;
      }
    }

    if (maxRisk <= 0) maxRisk = 1;

    // Normalized Score calculation: 100 - ((totalRisk / maxRisk) * 100)
    final double rawScore = 100.0 - ((totalRisk / maxRisk.toDouble()) * 100.0);
    final int score = rawScore.round().clamp(0, 100);

    // Status categorization
    String status;
    if (score >= 80) {
      status = 'HEALTHY';
    } else if (score >= 50) {
      status = 'WARNING';
    } else {
      status = 'CRITICAL';
    }

    // Issues & Recommendations collection
    final List<String> issues = [];
    final List<String> recommendations = [];
    final Map<String, String> answersSummary = {};

    userAnswers.forEach((qId, opt) {
      answersSummary[qId] = opt.label;

      if (opt.riskScore > 0) {
        if (opt.issueDescription != null && opt.issueDescription!.isNotEmpty) {
          if (!issues.contains(opt.issueDescription!)) {
            issues.add(opt.issueDescription!);
          }
        }
        if (opt.recommendation != null && opt.recommendation!.isNotEmpty) {
          if (!recommendations.contains(opt.recommendation!)) {
            recommendations.add(opt.recommendation!);
          }
        }
      }
    });

    if (issues.isEmpty) {
      issues.add('No active concerns or issues detected.');
    }

    if (recommendations.isEmpty) {
      recommendations.add('Continue standard maintenance schedule.');
    }

    final result = HealthResult(
      score: score,
      status: status,
      issues: issues,
      recommendations: recommendations,
      createdAt: DateTime.now(),
      applianceId: appliance.id,
      applianceName: appliance.name,
      applianceType: appliance.type,
      answers: answersSummary,
    );

    // Synchronize result with AnalysisService so it appears in overall app results & details
    _saveToAnalysisService(appliance, result);

    return result;
  }

  void _saveToAnalysisService(ApplianceModel appliance, HealthResult result) {
    final analysisModel = AnalysisModel(
      id: 'HEALTH-${DateTime.now().millisecondsSinceEpoch}',
      applianceId: appliance.id,
      applianceName: appliance.name,
      applianceType: appliance.type,
      analyzedAt: result.createdAt,
      healthCondition: '${result.score}% (${result.status})',
      detectedIssues: result.issues,
      recommendedAction: result.recommendations.first,
      diagnosticDetails: {
        'Health Score': '${result.score}%',
        'Status': result.status,
        'Total Questions': result.answers.length.toString(),
        'Last Scan': result.createdAt.toLocal().toString().split('.').first,
      },
    );

    AnalysisService().addExternalAnalysis(analysisModel);
  }
}
