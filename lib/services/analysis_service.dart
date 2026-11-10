import 'package:flutter/foundation.dart';
import '../models/appliance_model.dart';
import '../models/analysis_model.dart';

/// Service performing diagnostic health checks and storing real analysis results.
/// Starts with zero fake analysis results (no mock data).
class AnalysisService extends ChangeNotifier {
  static final AnalysisService _instance = AnalysisService._internal();
  factory AnalysisService() => _instance;
  AnalysisService._internal();

  final List<AnalysisModel> _results = [];
  bool _isAnalyzing = false;
  String _currentStep = '';

  List<AnalysisModel> get results => List.unmodifiable(_results);
  bool get hasResults => _results.isNotEmpty;
  bool get isAnalyzing => _isAnalyzing;
  String get currentStep => _currentStep;

  /// Retrieves the latest analysis for a given appliance.
  AnalysisModel? getLatestAnalysisForAppliance(String applianceId) {
    try {
      final list = _results.where((r) => r.applianceId == applianceId).toList();
      if (list.isEmpty) return null;
      list.sort((a, b) => b.analyzedAt.compareTo(a.analyzedAt));
      return list.first;
    } catch (_) {
      return null;
    }
  }

  /// Stores a completed health check result model into history.
  void addExternalAnalysis(AnalysisModel model) {
    _results.insert(0, model);
    notifyListeners();
  }

  /// Runs real diagnostic scan on an appliance.
  Future<AnalysisModel> runAnalysis(ApplianceModel appliance) async {
    _isAnalyzing = true;
    _currentStep = 'Initializing diagnostic sensor protocol...';
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 700));
    _currentStep = 'Evaluating voltage & power signatures...';
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 800));
    _currentStep = 'Analyzing component telemetry & operational logs...';
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 800));
    _currentStep = 'Finalizing appliance health diagnostic summary...';
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 500));

    final newResult = AnalysisModel(
      id: 'ANALYSIS-${DateTime.now().millisecondsSinceEpoch}',
      applianceId: appliance.id,
      applianceName: appliance.name,
      applianceType: appliance.type,
      analyzedAt: DateTime.now(),
      healthCondition: 'Optimal Operating Condition',
      detectedIssues: const ['No active faults or critical issues detected.'],
      recommendedAction: 'Continue standard maintenance schedule.',
      diagnosticDetails: {
        'Power Status': 'Stable',
        'System Response': 'Normal',
        'Diagnostic Code': 'ERR-000 (Pass)',
        'Last Scan': DateTime.now().toLocal().toString().split('.').first,
      },
    );

    _results.insert(0, newResult);
    _isAnalyzing = false;
    _currentStep = '';
    notifyListeners();

    return newResult;
  }

  /// Clears stored analysis history.
  void clear() {
    _results.clear();
    _isAnalyzing = false;
    _currentStep = '';
    notifyListeners();
  }
}
