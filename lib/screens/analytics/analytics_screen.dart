import 'package:flutter/material.dart';
import '../../services/appliance_service.dart';
import '../../services/analysis_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_text_styles.dart';
import '../../widgets/empty_state.dart';

/// Analytics screen displaying real diagnostics data when available, or clean empty state.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final applianceService = ApplianceService();
    final analysisService = AnalysisService();

    return ListenableBuilder(
      listenable: Listenable.merge([applianceService, analysisService]),
      builder: (context, _) {
        final appliances = applianceService.appliances;
        final results = analysisService.results;
        final hasData = appliances.isNotEmpty || results.isNotEmpty;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Analytics'),
            automaticallyImplyLeading: false,
          ),
          body: SafeArea(
            child: !hasData
                ? const EmptyStateWidget(
                    icon: Icons.bar_chart_rounded,
                    title: 'No analytics available yet',
                    subtitle: 'Analytics will appear when appliance data is available.',
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Appliance Overview',
                          style: AppTextStyles.heading2,
                        ),
                        const SizedBox(height: 16),

                        // Real Metrics Summary Cards
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.borderColor),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Total Appliances', style: AppTextStyles.caption),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${appliances.length}',
                                      style: AppTextStyles.heading1.copyWith(
                                        color: AppColors.primaryBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.borderColor),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Scans Completed', style: AppTextStyles.caption),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${results.length}',
                                      style: AppTextStyles.heading1.copyWith(
                                        color: AppColors.primaryBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        Text('Diagnostic History', style: AppTextStyles.heading3),
                        const SizedBox(height: 12),

                        if (results.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.borderColor),
                            ),
                            child: Text(
                              'No diagnostics executed yet. Run an analysis from the appliance details page.',
                              style: AppTextStyles.subtitle,
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: results.length,
                            itemBuilder: (context, index) {
                              final item = results[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.borderColor),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.applianceName,
                                          style: AppTextStyles.heading3.copyWith(fontSize: 15),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.analyzedAt
                                              .toLocal()
                                              .toString()
                                              .split('.')
                                              .first,
                                          style: AppTextStyles.caption,
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        item.healthCondition,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}
