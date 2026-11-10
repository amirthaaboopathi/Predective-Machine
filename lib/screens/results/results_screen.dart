import 'package:flutter/material.dart';
import '../../services/analysis_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_text_styles.dart';
import '../../widgets/empty_state.dart';

/// Dedicated Results tab listing all completed appliance analysis reports.
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final analysisService = AnalysisService();

    return ListenableBuilder(
      listenable: analysisService,
      builder: (context, _) {
        final results = analysisService.results;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Analysis Results'),
            automaticallyImplyLeading: false,
          ),
          body: SafeArea(
            child: results.isEmpty
                ? const EmptyStateWidget(
                    icon: Icons.assignment_outlined,
                    title: 'No analysis results yet',
                    subtitle: 'Your appliance analysis results will appear here.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20.0),
                    physics: const BouncingScrollPhysics(),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final item = results[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderColor, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.shadowColor,
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/result-screen',
                                arguments: item,
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppColors.lightBlue,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.assignment_turned_in_outlined,
                                      color: AppColors.primaryBlue,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.applianceName,
                                          style: AppTextStyles.heading3.copyWith(fontSize: 16),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Scan Date: ${item.analyzedAt.toLocal().toString().split('.').first}',
                                          style: AppTextStyles.caption,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.secondaryText,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}
