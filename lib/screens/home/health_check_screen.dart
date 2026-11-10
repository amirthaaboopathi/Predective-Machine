import 'package:flutter/material.dart';
import '../../models/appliance_model.dart';
import '../../models/health_question.dart';
import '../../models/health_option.dart';
import '../../models/health_result.dart';
import '../../services/health_check_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_text_styles.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/primary_button.dart';

/// Screen executing step-by-step appliance-specific health check questionnaire.
class HealthCheckScreen extends StatefulWidget {
  final ApplianceModel appliance;

  const HealthCheckScreen({
    super.key,
    required this.appliance,
  });

  @override
  State<HealthCheckScreen> createState() => _HealthCheckScreenState();
}

class _HealthCheckScreenState extends State<HealthCheckScreen> {
  final _healthCheckService = HealthCheckService();
  
  List<HealthQuestion> _questions = [];
  int _currentIndex = 0;
  final Map<String, HealthOption> _userAnswers = {};
  HealthResult? _completedResult;

  @override
  void initState() {
    super.initState();
    _questions = _healthCheckService.getQuestionsForApplianceType(widget.appliance.type);
  }

  void _handleOptionSelect(HealthQuestion question, HealthOption option) {
    setState(() {
      _userAnswers[question.id] = option;
    });
  }

  void _handleNext() {
    final currentQuestion = _questions[_currentIndex];
    if (!_userAnswers.containsKey(currentQuestion.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an answer.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      // Assessment completed
      final result = _healthCheckService.calculateHealthResult(
        appliance: widget.appliance,
        userAnswers: _userAnswers,
      );
      setState(() {
        _completedResult = result;
      });
    }
  }

  void _handlePrevious() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Health Check'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: EmptyStateWidget(
            icon: Icons.assignment_late_outlined,
            title: 'Health Check Unavailable',
            subtitle:
                'Health questions for ${widget.appliance.type} are coming soon.',
            buttonText: 'Back to Appliance',
            onButtonPressed: () => Navigator.pop(context),
          ),
        ),
      );
    }

    if (_completedResult != null) {
      return _buildResultView(context, _completedResult!);
    }

    final currentQuestion = _questions[_currentIndex];
    final selectedOption = _userAnswers[currentQuestion.id];
    final progress = (_currentIndex + 1) / _questions.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Health Check'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Appliance Header Summary Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderColor, width: 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.lightBlue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.health_and_safety_outlined,
                              color: AppColors.primaryBlue,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.appliance.name,
                                  style: AppTextStyles.heading3.copyWith(fontSize: 16),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${widget.appliance.type} Health Assessment',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Progress Header & Linear Indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Question ${_currentIndex + 1} of ${_questions.length}',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        Text(
                          '${(progress * 100).round()}%',
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: AppColors.primaryBlueLight,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Question Prompt Title
                    Text(
                      currentQuestion.question,
                      style: AppTextStyles.heading2.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 20),

                    // Options List
                    ...currentQuestion.options.map((option) {
                      final isSelected = selectedOption?.id == option.id;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryBlueLight : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppColors.primaryBlue : AppColors.borderColor,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _handleOptionSelect(currentQuestion, option),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? AppColors.primaryBlue
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primaryBlue
                                            : AppColors.secondaryText,
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check_rounded,
                                            size: 14,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      option.label,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: isSelected
                                            ? AppColors.primaryBlue
                                            : AppColors.darkText,
                                        fontWeight:
                                            isSelected ? FontWeight.bold : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Bottom Navigation Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(color: AppColors.borderColor, width: 1),
                ),
              ),
              child: Row(
                children: [
                  if (_currentIndex > 0) ...[
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: _handlePrevious,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          side: const BorderSide(color: AppColors.borderColor, width: 1.5),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: PrimaryButton(
                      text: _currentIndex == _questions.length - 1
                          ? 'Complete Assessment'
                          : 'Next',
                      onPressed: _handleNext,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultView(BuildContext context, HealthResult result) {
    Color statusColor;
    IconData statusIcon;

    if (result.status == 'HEALTHY') {
      statusColor = AppColors.success;
      statusIcon = Icons.check_circle_outline_rounded;
    } else if (result.status == 'WARNING') {
      statusColor = AppColors.warning;
      statusIcon = Icons.warning_amber_rounded;
    } else {
      statusColor = AppColors.error;
      statusIcon = Icons.error_outline_rounded;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Health Check Result'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Appliance Title Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.applianceName,
                      style: AppTextStyles.heading2.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      result.applianceType,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Score Gauge Badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.borderColor, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowColor,
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'HEALTH SCORE',
                      style: AppTextStyles.caption.copyWith(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${result.score}%',
                      style: AppTextStyles.heading1.copyWith(
                        fontSize: 54,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 18, color: statusColor),
                          const SizedBox(width: 6),
                          Text(
                            result.status,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Detected Concerns Section
              Text('Detected Concerns', style: AppTextStyles.heading3),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: result.issues.map((issue) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            result.status == 'HEALTHY'
                                ? Icons.check_circle_outline
                                : Icons.warning_amber_rounded,
                            size: 18,
                            color: result.status == 'HEALTHY'
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              issue,
                              style: AppTextStyles.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Recommendations Section
              Text('Recommendations', style: AppTextStyles.heading3),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: result.recommendations.map((rec) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.arrow_right_rounded,
                            size: 20,
                            color: AppColors.primaryBlue,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              rec,
                              style: AppTextStyles.body,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 32),

              PrimaryButton(
                text: 'Done',
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
