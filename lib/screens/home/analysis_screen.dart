import 'package:flutter/material.dart';
import '../../models/appliance_model.dart';
import '../../services/analysis_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_text_styles.dart';

/// Screen performing real diagnostic analysis with dynamic loading status.
class AnalysisScreen extends StatefulWidget {
  final ApplianceModel appliance;

  const AnalysisScreen({
    super.key,
    required this.appliance,
  });

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  @override
  void initState() {
    super.initState();
    _startAnalysis();
  }

  Future<void> _startAnalysis() async {
    final analysisService = AnalysisService();
    final result = await analysisService.runAnalysis(widget.appliance);

    if (!mounted) return;

    Navigator.pushReplacementNamed(
      context,
      '/result-screen',
      arguments: result,
    );
  }

  @override
  Widget build(BuildContext context) {
    final analysisService = AnalysisService();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Appliance Analysis'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: analysisService,
          builder: (context, _) {
            final stepText = analysisService.currentStep.isNotEmpty
                ? analysisService.currentStep
                : 'Analyzing appliance telemetry...';

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Animated Scanning Graphic
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          color: AppColors.primaryBlue,
                          backgroundColor: AppColors.primaryBlueLight,
                        ),
                      ),
                      Container(
                        width: 110,
                        height: 110,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryBlueLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.search_rounded,
                          size: 50,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // Appliance Name Title
                  Text(
                    'Analyzing ${widget.appliance.name}',
                    style: AppTextStyles.heading2,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.appliance.type,
                    style: AppTextStyles.subtitle,
                  ),
                  const SizedBox(height: 32),

                  // Dynamic Progress Status Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Status',
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          stepText,
                          style: AppTextStyles.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
