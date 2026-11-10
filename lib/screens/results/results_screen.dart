import 'package:flutter/material.dart';
import '../../models/appliance_model.dart';
import '../../models/sensor_reading_model.dart';
import '../../services/appliance_service.dart';
import '../../services/sensor_service.dart';
import '../../services/analysis_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_text_styles.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final _sensorService = SensorService();
  final _applianceService = ApplianceService();
  final _analysisService = AnalysisService();

  String? _selectedApplianceId;

  Color _getStatusColor(String condition) {
    switch (condition) {
      case 'Normal':
      case 'Optimal':
        return const Color(0xFF10B981);
      case 'Warning':
      case 'Elevated':
        return const Color(0xFFF59E0B);
      case 'Critical':
      case 'Hazard':
        return const Color(0xFFEF4444);
      default:
        return AppColors.secondaryText;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_sensorService, _applianceService, _analysisService]),
      builder: (context, _) {
        final appliances = _applianceService.appliances;
        final targetApplianceId = _selectedApplianceId ?? (appliances.isNotEmpty ? appliances.first.id : '');
        final targetAppliance = appliances.firstWhere(
          (a) => a.id == targetApplianceId,
          orElse: () => appliances.isNotEmpty
              ? appliances.first
              : ApplianceModel(
                  id: '',
                  userId: '',
                  name: 'No Appliance',
                  type: 'Unknown',
                  addedAt: DateTime.fromMillisecondsSinceEpoch(0),
                ),
        );

        final readings = targetAppliance.id.isNotEmpty
            ? _sensorService.getReadingsForAppliance(targetAppliance.id, targetAppliance.name)
            : <SensorReadingModel>[];

        final latestReading = readings.isNotEmpty ? readings.first : null;
        final previousReading = readings.length > 1 ? readings[1] : null;
        final diagnosticReports = _analysisService.results
            .where((r) => r.applianceId == targetAppliance.id)
            .toList();

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Operating Assessment'),
            automaticallyImplyLeading: false,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Appliance Switcher
                  if (appliances.isNotEmpty) ...[
                    _buildApplianceSelector(appliances, targetApplianceId),
                    const SizedBox(height: 16),
                  ],

                  if (latestReading == null) ...[
                    _buildNoDataCard(targetAppliance),
                  ] else ...[
                    // 1. Overall Assessment Card
                    _buildOverallAssessmentCard(latestReading, readings),
                    const SizedBox(height: 20),

                    // 2. Individual Sensor Results
                    Text(
                      'Monitored Parameters Condition',
                      style: AppTextStyles.heading3,
                    ),
                    const SizedBox(height: 12),
                    _buildParameterConditionCard(
                      parameterName: 'Appliance Temperature',
                      latestValue: '${latestReading.temperature} °C',
                      referenceRange: '20.0 °C - 55.0 °C',
                      icon: Icons.thermostat_rounded,
                      accentColor: const Color(0xFF0284C7),
                      condition: _evaluateTempCondition(latestReading.temperature),
                      comparison: _compareReadings(
                        latestReading.temperature,
                        previousReading?.temperature,
                        '°C',
                      ),
                      explanation: _getTempExplanation(latestReading.temperature),
                    ),
                    const SizedBox(height: 12),
                    _buildParameterConditionCard(
                      parameterName: 'Appliance Vibration',
                      latestValue: '${latestReading.vibration} G',
                      referenceRange: '0.10 G - 0.40 G',
                      icon: Icons.vibration_rounded,
                      accentColor: const Color(0xFF7C3AED),
                      condition: _evaluateVibCondition(latestReading.vibration),
                      comparison: _compareReadings(
                        latestReading.vibration,
                        previousReading?.vibration,
                        'G',
                      ),
                      explanation: _getVibExplanation(latestReading.vibration),
                    ),
                    const SizedBox(height: 12),
                    _buildParameterConditionCard(
                      parameterName: 'Operating Sound Level',
                      latestValue: '${latestReading.sound.round()} dB',
                      referenceRange: '30 dB - 60 dB',
                      icon: Icons.graphic_eq_rounded,
                      accentColor: const Color(0xFF0D9488),
                      condition: _evaluateSoundCondition(latestReading.sound),
                      comparison: _compareReadings(
                        latestReading.sound,
                        previousReading?.sound,
                        'dB',
                      ),
                      explanation: _getSoundExplanation(latestReading.sound),
                    ),
                    const SizedBox(height: 20),

                    // 3. Intelligent Monitoring Insights
                    Text(
                      'Intelligent Monitoring Insights',
                      style: AppTextStyles.heading3,
                    ),
                    const SizedBox(height: 12),
                    _buildInsightsCard(latestReading, previousReading),
                    const SizedBox(height: 24),
                  ],

                  // 4. Historical Diagnostic Assessment Reports
                  Text(
                    'Historical Assessment Reports',
                    style: AppTextStyles.heading3,
                  ),
                  const SizedBox(height: 12),
                  _buildHistoricalReportsSection(diagnosticReports),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // EVALUATION & EXPLANATION HELPERS
  // ===========================================================================

  String _evaluateTempCondition(double temp) {
    if (temp <= 55.0) return 'Optimal';
    if (temp <= 70.0) return 'Elevated';
    return 'Critical';
  }

  String _getTempExplanation(double temp) {
    if (temp <= 55.0) {
      return 'Temperature is within normal thermal limits for everyday household operation.';
    } else if (temp <= 70.0) {
      return 'Temperature is slightly elevated. Verify airflow vents and ensure room ventilation is clear.';
    } else {
      return 'Critical temperature hazard detected. Power off appliance immediately to prevent component damage.';
    }
  }

  String _evaluateVibCondition(double vib) {
    if (vib <= 0.40) return 'Optimal';
    if (vib <= 0.80) return 'Elevated';
    return 'Critical';
  }

  String _getVibExplanation(double vib) {
    if (vib <= 0.40) {
      return 'Mechanical stability is steady with smooth motor rotational balance.';
    } else if (vib <= 0.80) {
      return 'Noticeable mechanical oscillation detected. Inspect foot levelers or internal laundry balance.';
    } else {
      return 'Excessive vibration detected. Potential loose mechanical mountings, worn bearings, or severe imbalance.';
    }
  }

  String _evaluateSoundCondition(double sound) {
    if (sound <= 60.0) return 'Optimal';
    if (sound <= 75.0) return 'Elevated';
    return 'Critical';
  }

  String _getSoundExplanation(double sound) {
    if (sound <= 60.0) {
      return 'Acoustic emissions are quiet and consistent with baseline standards.';
    } else if (sound <= 75.0) {
      return 'Operating sound is elevated. May indicate active high-power cycle or fan hum.';
    } else {
      return 'Acoustic noise exceeds acceptable standards. Potential mechanical rubbing or compressor strain.';
    }
  }

  String _compareReadings(double current, double? previous, String unit) {
    if (previous == null) return 'Initial recording';
    final diff = current - previous;
    if (diff.abs() < 0.1) return 'Identical to prior recording';
    final sign = diff > 0 ? '+' : '';
    return '$sign${diff.toStringAsFixed(1)} $unit vs previous';
  }

  // ===========================================================================
  // SUB-WIDGETS
  // ===========================================================================

  Widget _buildApplianceSelector(List<ApplianceModel> appliances, String currentId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentId.isNotEmpty ? currentId : appliances.first.id,
          isExpanded: true,
          items: appliances.map((a) {
            return DropdownMenuItem(
              value: a.id,
              child: Text(
                '${a.name} (${a.type})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedApplianceId = val);
            }
          },
        ),
      ),
    );
  }

  Widget _buildOverallAssessmentCard(
    SensorReadingModel latest,
    List<SensorReadingModel> readings,
  ) {
    final isTempOk = latest.temperature <= 55.0;
    final isVibOk = latest.vibration <= 0.40;
    final isSoundOk = latest.sound <= 60.0;

    String overallStatus;
    Color statusColor;
    String statusDescription;

    if (isTempOk && isVibOk && isSoundOk) {
      overallStatus = 'Operating Normally';
      statusColor = const Color(0xFF10B981);
      statusDescription = 'All parameters are within verified operating thresholds.';
    } else if (latest.temperature > 70 || latest.vibration > 0.80 || latest.sound > 75) {
      overallStatus = 'Abnormal Condition Detected';
      statusColor = const Color(0xFFEF4444);
      statusDescription = 'One or more parameters exceed safe operational limits.';
    } else {
      overallStatus = 'Attention Required';
      statusColor = const Color(0xFFF59E0B);
      statusDescription = 'Elevated operating readings detected. Inspection recommended.';
    }

    final warningCount = readings.where((r) => r.temperature > 55 || r.vibration > 0.40 || r.sound > 60).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Overall Operational State',
                style: AppTextStyles.caption.copyWith(color: AppColors.secondaryText),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  overallStatus,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            overallStatus,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            statusDescription,
            style: AppTextStyles.bodyMedium,
          ),
          const Divider(height: 24, color: AppColors.dividerColor),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recorded Warnings: $warningCount',
                style: AppTextStyles.caption,
              ),
              Text(
                'Last assessed: ${_formatShortTime(latest.recordedAt)}',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParameterConditionCard({
    required String parameterName,
    required String latestValue,
    required String referenceRange,
    required IconData icon,
    required Color accentColor,
    required String condition,
    required String comparison,
    required String explanation,
  }) {
    final condColor = _getStatusColor(condition);

    return Container(
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(parameterName, style: AppTextStyles.heading3.copyWith(fontSize: 14)),
                    Text(
                      'Reference: $referenceRange',
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    latestValue,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: condColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      condition,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: condColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            explanation,
            style: AppTextStyles.bodyMedium.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            comparison,
            style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsCard(SensorReadingModel latest, SensorReadingModel? previous) {
    final List<String> insights = [];

    if (latest.temperature <= 55.0) {
      insights.add('Appliance temperature is within the optimal operating range.');
    } else {
      insights.add('Thermal sensors indicate elevated heat output compared to benchmark standard.');
    }

    if (previous != null) {
      if (latest.vibration > previous.vibration + 0.05) {
        insights.add('Vibration has increased compared with the previous monitoring period.');
      } else if (latest.vibration < previous.vibration - 0.05) {
        insights.add('Vibration levels have stabilized and improved.');
      }

      if (latest.sound > 62.0) {
        insights.add('Operating sound levels are currently elevated above the baseline reference.');
      } else {
        insights.add('Acoustic decibel readings remain within quiet background levels.');
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: insights.map((insight) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 16,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    insight,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1E3A8A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHistoricalReportsSection(List<dynamic> reports) {
    if (reports.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Text(
          'No formal diagnostic assessments generated yet. Run a telemetry scan from the home dashboard or appliance details screen.',
          style: AppTextStyles.caption,
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.healthCondition,
                    style: AppTextStyles.heading3.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Assessed: ${_formatShortTime(report.analyzedAt)}',
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                ],
              ),
              OutlinedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/result-screen',
                    arguments: report,
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('View Report', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoDataCard(ApplianceModel appliance) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          const Icon(Icons.assignment_late_outlined, size: 40, color: Colors.blueGrey),
          const SizedBox(height: 12),
          Text(
            'No Monitoring Assessment Available',
            style: AppTextStyles.heading3.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'Connect your monitoring device to begin receiving temperature, vibration, and sound telemetry for "${appliance.name}".',
            style: AppTextStyles.subtitle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatShortTime(DateTime dt) {
    return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
