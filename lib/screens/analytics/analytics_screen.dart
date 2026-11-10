import 'package:flutter/material.dart';
import '../../models/appliance_model.dart';
import '../../services/appliance_service.dart';
import '../../services/sensor_service.dart';
import '../../services/sensor_analytics_service.dart';
import '../../services/hardware_serial_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_text_styles.dart';
import '../../widgets/interactive_chart.dart';

/// Screen presenting comprehensive sensor analytics, real-time plotted trendlines,
/// statistical metrics, and predictive failure analysis.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _sensorService = SensorService();
  final _applianceService = ApplianceService();
  final _hardwareService = HardwareSerialService();

  AnalyticsTimeRange _selectedRange = AnalyticsTimeRange.allTime;
  String? _selectedApplianceId;
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _sensorService.fetchAllSensorReadings();
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 90)),
      lastDate: now,
      initialDateRange: _customRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primaryBlue),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customRange = picked;
      });
    }
  }

  String _getTrendLabel(ParameterTrend trend) {
    switch (trend) {
      case ParameterTrend.rising:
        return 'Rising';
      case ParameterTrend.falling:
        return 'Falling';
      case ParameterTrend.stable:
        return 'Stable';
    }
  }

  IconData _getTrendIcon(ParameterTrend trend) {
    switch (trend) {
      case ParameterTrend.rising:
        return Icons.trending_up_rounded;
      case ParameterTrend.falling:
        return Icons.trending_down_rounded;
      case ParameterTrend.stable:
        return Icons.trending_flat_rounded;
    }
  }

  Color _getTrendColor(ParameterTrend trend, {bool reverse = false}) {
    switch (trend) {
      case ParameterTrend.rising:
        return reverse ? AppColors.warning : AppColors.primaryBlue;
      case ParameterTrend.falling:
        return AppColors.success;
      case ParameterTrend.stable:
        return AppColors.secondaryText;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_sensorService, _applianceService, _hardwareService]),
      builder: (context, _) {
        final appliances = _applianceService.appliances;

        // Filter by appliance if selected
        final allReadings = _selectedApplianceId != null
            ? _sensorService.getReadingsForAppliance(_selectedApplianceId!)
            : _sensorService.allReadings;

        // Filter by time range
        var filteredReadings = SensorAnalyticsService.filterReadings(
          allReadings,
          _selectedRange,
          customRange: _customRange,
        );

        // Fallback: if time-range yields empty but records exist, show all readings
        if (filteredReadings.isEmpty && allReadings.isNotEmpty) {
          filteredReadings = List.from(allReadings);
        }

        final summary = SensorAnalyticsService.computeAnalytics(filteredReadings);
        final hasData = filteredReadings.isNotEmpty;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Sensor Analytics & Predictions'),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.sync_rounded),
                tooltip: 'Refresh Telemetry',
                onPressed: () => _sensorService.fetchAllSensorReadings(),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Appliance Selector Filter (if multiple appliances exist)
                  if (appliances.isNotEmpty) ...[
                    _buildApplianceFilter(appliances),
                    const SizedBox(height: 14),
                  ],

                  // Time Range Filter Bar
                  _buildTimeRangeSelector(),
                  const SizedBox(height: 20),

                  if (!hasData) ...[
                    _buildEmptyState(),
                  ] else ...[
                    // Combined Executive Performance Summary
                    _buildExecutiveSummaryCard(summary),
                    const SizedBox(height: 24),

                    // PREDICTIVE FAILURE ANALYSIS & RUL FORECAST
                    _buildPredictiveFailureSection(summary),
                    const SizedBox(height: 24),

                    // 1. TEMPERATURE ANALYTICS & TREND GRAPH
                    _buildParameterSection(
                      title: 'Appliance Temperature',
                      subtitle: 'Thermal variations and component heating profile',
                      icon: Icons.thermostat_rounded,
                      accentColor: const Color(0xFF0284C7),
                      stats: summary.temperature,
                      points: summary.filteredReadings
                          .map((r) => ChartDataPoint(timestamp: r.recordedAt, value: r.temperature))
                          .toList(),
                      thresholdValue: 55.0,
                      thresholdLabel: 'Optimal limit (55°C)',
                    ),
                    const SizedBox(height: 24),

                    // 2. VIBRATION ANALYTICS & TREND GRAPH
                    _buildParameterSection(
                      title: 'Appliance Vibration',
                      subtitle: 'Dynamic mechanical oscillation and motor stability',
                      icon: Icons.vibration_rounded,
                      accentColor: const Color(0xFF7C3AED),
                      stats: summary.vibration,
                      points: summary.filteredReadings
                          .map((r) => ChartDataPoint(timestamp: r.recordedAt, value: r.vibration))
                          .toList(),
                      thresholdValue: 0.40,
                      thresholdLabel: 'Smooth baseline (0.40 G)',
                    ),
                    const SizedBox(height: 24),

                    // 3. SOUND ANALYTICS & TREND GRAPH
                    _buildParameterSection(
                      title: 'Operating Sound Level',
                      subtitle: 'Acoustic emissions and background noise levels',
                      icon: Icons.graphic_eq_rounded,
                      accentColor: const Color(0xFF0D9488),
                      stats: summary.sound,
                      points: summary.filteredReadings
                          .map((r) => ChartDataPoint(timestamp: r.recordedAt, value: r.sound))
                          .toList(),
                      thresholdValue: 62.0,
                      thresholdLabel: 'Quiet threshold (62 dB)',
                    ),
                    const SizedBox(height: 32),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // SUB-WIDGETS
  // ===========================================================================



  Widget _buildApplianceFilter(List<ApplianceModel> appliances) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedApplianceId,
          isExpanded: true,
          hint: const Text('All Monitored Appliances'),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All Monitored Appliances', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ...appliances.map(
              (a) => DropdownMenuItem<String?>(
                value: a.id,
                child: Text('${a.name} (${a.type})'),
              ),
            ),
          ],
          onChanged: (val) {
            setState(() {
              _selectedApplianceId = val;
            });
          },
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    final ranges = [
      {'label': '1H', 'value': AnalyticsTimeRange.oneHour},
      {'label': '6H', 'value': AnalyticsTimeRange.sixHours},
      {'label': '24H', 'value': AnalyticsTimeRange.oneDay},
      {'label': '7D', 'value': AnalyticsTimeRange.sevenDays},
      {'label': '30D', 'value': AnalyticsTimeRange.thirtyDays},
      {'label': 'All', 'value': AnalyticsTimeRange.allTime},
      {'label': 'Custom', 'value': null},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ranges.map((item) {
          final isCustom = item['value'] == null;
          final isSelected = isCustom
              ? _customRange != null
              : (_selectedRange == item['value'] && _customRange == null);

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(item['label'] as String),
              selected: isSelected,
              selectedColor: AppColors.primaryBlue.withValues(alpha: 0.15),
              backgroundColor: AppColors.surface,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primaryBlue : AppColors.secondaryText,
              ),
              side: BorderSide(
                color: isSelected ? AppColors.primaryBlue : AppColors.borderColor,
                width: 1,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              onSelected: (_) {
                if (isCustom) {
                  _pickCustomRange();
                } else {
                  setState(() {
                    _customRange = null;
                    _selectedRange = item['value'] as AnalyticsTimeRange;
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExecutiveSummaryCard(ApplianceAnalyticsSummary summary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 14,
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
                'Monitoring Period Summary',
                style: AppTextStyles.heading3.copyWith(fontSize: 15),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: summary.totalAbnormalEvents == 0
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  summary.totalAbnormalEvents == 0
                      ? 'Optimal Operation'
                      : '${summary.totalAbnormalEvents} Warnings Recorded',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: summary.totalAbnormalEvents == 0
                        ? const Color(0xFF047857)
                        : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'Total Records',
                  value: '${summary.totalReadings}',
                  subtitle: 'Data points analyzed',
                  accentColor: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  title: 'Abnormal Events',
                  value: '${summary.totalAbnormalEvents}',
                  subtitle: summary.mostFrequentAbnormalParam != 'None'
                      ? 'Highest: ${summary.mostFrequentAbnormalParam.split(' ').first}'
                      : 'None detected',
                  accentColor: summary.totalAbnormalEvents == 0
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PREDICTIVE FAILURE ANALYSIS CARD & RUL FORECAST
  // ===========================================================================

  Widget _buildPredictiveFailureSection(ApplianceAnalyticsSummary summary) {
    final pred = summary.predictiveFailure;

    Color riskColor;
    String riskLabel;
    IconData riskIcon;

    switch (pred.riskLevel) {
      case FailureRiskLevel.low:
        riskColor = const Color(0xFF10B981);
        riskLabel = 'Low Risk (Healthy)';
        riskIcon = Icons.verified_user_rounded;
        break;
      case FailureRiskLevel.moderate:
        riskColor = const Color(0xFFF59E0B);
        riskLabel = 'Moderate Risk';
        riskIcon = Icons.warning_amber_rounded;
        break;
      case FailureRiskLevel.high:
        riskColor = const Color(0xFFEA580C);
        riskLabel = 'High Degradation Risk';
        riskIcon = Icons.error_outline_rounded;
        break;
      case FailureRiskLevel.critical:
        riskColor = const Color(0xFFEF4444);
        riskLabel = 'Critical Risk — Failure Imminent';
        riskIcon = Icons.dangerous_rounded;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: riskColor.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: riskColor.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title and Risk Level Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: riskColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(riskIcon, color: riskColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Predictive Failure Analysis',
                        style: AppTextStyles.heading3.copyWith(fontSize: 16),
                      ),
                      Text(
                        'Remaining Useful Life (RUL) & Health Degradation',
                        style: AppTextStyles.caption.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: riskColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  riskLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: riskColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Primary Risk Metric Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  riskColor.withValues(alpha: 0.06),
                  riskColor.withValues(alpha: 0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: riskColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Failure Probability Score',
                      style: TextStyle(fontSize: 12, color: AppColors.secondaryText, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pred.failureRiskPercent}%',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: riskColor,
                      ),
                    ),
                  ],
                ),
                Container(width: 1, height: 40, color: riskColor.withValues(alpha: 0.2)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Est. Days to Maintenance',
                      style: TextStyle(fontSize: 12, color: AppColors.secondaryText, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pred.estimatedDaysToFailure} Days',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Component Stress Factor Breakdown
          Text(
            'Component Stress Indicators',
            style: AppTextStyles.heading3.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 10),
          _buildStressBar('Thermal Breakdown Stress', pred.thermalStressScore, const Color(0xFF0284C7)),
          const SizedBox(height: 8),
          _buildStressBar('Mechanical Bearing Oscillation', pred.mechanicalStressScore, const Color(0xFF7C3AED)),
          const SizedBox(height: 8),
          _buildStressBar('Acoustic Cavitation & Friction', pred.acousticStressScore, const Color(0xFF0D9488)),
          const SizedBox(height: 16),

          // Primary Factor & Failure Mode Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.psychology_outlined, size: 18, color: AppColors.primaryBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Primary Diagnostic Factor: ${pred.primaryRiskFactor}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Mode: ${pred.predictedFailureMode}',
                  style: AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.secondaryText),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Failure Probability Trend Chart
          if (pred.riskProgressionCurve.isNotEmpty) ...[
            Text(
              'Failure Probability Progression (% Risk Curve)',
              style: AppTextStyles.heading3.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 8),
            InteractiveSensorChart(
              points: pred.riskProgressionCurve
                  .map((p) => ChartDataPoint(timestamp: p.timestamp, value: p.riskPercent))
                  .toList(),
              unit: '%',
              primaryColor: riskColor,
              thresholdValue: 50.0,
              thresholdLabel: 'Elevated Risk (50%)',
              height: 160,
            ),
            const SizedBox(height: 16),
          ],

          // Preventative Action Steps
          Text(
            'Recommended Preventative Actions',
            style: AppTextStyles.heading3.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 8),
          ...pred.preventativeRecommendations.map((action) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      action,
                      style: AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.darkText),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStressBar(String label, double score, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
            Text('${score.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (score / 100.0).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: Colors.grey.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.caption.copyWith(fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildParameterSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required ParameterStats stats,
    required List<ChartDataPoint> points,
    required double thresholdValue,
    required String thresholdLabel,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
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
                    Text(title, style: AppTextStyles.heading3.copyWith(fontSize: 15)),
                    Text(subtitle, style: AppTextStyles.caption.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              // Trend indicator
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getTrendIcon(stats.trend),
                    size: 16,
                    color: _getTrendColor(stats.trend),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getTrendLabel(stats.trend),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getTrendColor(stats.trend),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4-Stat Box: Min, Max, Avg, Latest
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderColor, width: 0.8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatPill('Latest', '${stats.latest} ${stats.unit}', accentColor),
                _buildDivider(),
                _buildStatPill('Average', '${stats.average} ${stats.unit}', AppColors.darkText),
                _buildDivider(),
                _buildStatPill('Min', '${stats.min} ${stats.unit}', Colors.grey[700]!),
                _buildDivider(),
                _buildStatPill('Max', '${stats.max} ${stats.unit}', Colors.grey[700]!),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Trend Chart
          InteractiveSensorChart(
            points: points,
            unit: stats.unit,
            primaryColor: accentColor,
            thresholdValue: thresholdValue,
            thresholdLabel: thresholdLabel,
            height: 180,
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.secondaryText)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 24, color: AppColors.borderColor);
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.analytics_outlined,
              size: 40,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Telemetry Recorded For This Timeframe',
            style: AppTextStyles.heading3.copyWith(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Connect your monitoring device or adjust the timeframe filter to view historical trends.',
            style: AppTextStyles.subtitle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
