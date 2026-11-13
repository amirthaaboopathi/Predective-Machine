import 'package:flutter/material.dart';
import '../models/appliance_model.dart';
import '../models/analysis_model.dart';
import '../models/appliance_health_metrics.dart';
import '../models/sensor_reading_model.dart';
import '../services/hardware_serial_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';

/// Card widget representing an individual appliance on the dashboard
/// displaying hardware link status, real-time sensor metrics (temperature, vibration, sound)
/// and diagnostic health condition.
class ApplianceCard extends StatelessWidget {
  final ApplianceModel appliance;
  final AnalysisModel? latestAnalysis;
  final ApplianceHealthMetrics? healthMetrics;
  final SensorReadingModel? latestReading;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ApplianceCard({
    super.key,
    required this.appliance,
    this.latestAnalysis,
    this.healthMetrics,
    this.latestReading,
    required this.onTap,
    this.onLongPress,
  });

  IconData _getApplianceIcon(String type) {
    switch (type.toLowerCase()) {
      case 'refrigerator':
        return Icons.kitchen_outlined;
      case 'washing machine':
        return Icons.local_laundry_service_outlined;
      case 'air conditioner':
        return Icons.ac_unit_outlined;
      case 'television':
        return Icons.tv_outlined;
      case 'fan':
        return Icons.air_outlined;
      case 'microwave':
        return Icons.microwave_outlined;
      default:
        return Icons.devices_outlined;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Good':
        return AppColors.success;
      case 'Average':
        return AppColors.warning;
      case 'Poor':
        return AppColors.error;
      default:
        return AppColors.secondaryText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconData = _getApplianceIcon(appliance.type);
    final hasTelemetry = healthMetrics != null && healthMetrics!.readingCount > 0;
    final hardwareService = HardwareSerialService();
    final isLinkedHardware = appliance.isHardwareMonitored;
    final isActivelyStreaming = isLinkedHardware &&
        hardwareService.isActive &&
        hardwareService.activePort == appliance.hardwarePort;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActivelyStreaming
              ? AppColors.primaryBlue.withValues(alpha: 0.5)
              : AppColors.borderColor,
          width: isActivelyStreaming ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isActivelyStreaming
                ? AppColors.primaryBlue.withValues(alpha: 0.08)
                : AppColors.shadowColor,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Icon + Title/Brand + Hardware Badge / Status + Arrow
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Appliance Icon Container
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isActivelyStreaming
                            ? const Color(0xFFEFF6FF)
                            : AppColors.lightBlue,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        iconData,
                        size: 26,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  appliance.name,
                                  style: AppTextStyles.heading3.copyWith(fontSize: 15),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isLinkedHardware) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isActivelyStreaming
                                        ? AppColors.success.withValues(alpha: 0.15)
                                        : Colors.grey.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.sensors_rounded,
                                        size: 11,
                                        color: isActivelyStreaming
                                            ? AppColors.success
                                            : AppColors.secondaryText,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        appliance.hardwarePort!,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isActivelyStreaming
                                              ? AppColors.success
                                              : AppColors.secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            appliance.brand != null && appliance.brand!.isNotEmpty
                                ? '${appliance.brand} • ${appliance.type}'
                                : appliance.type,
                            style: AppTextStyles.caption.copyWith(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Health Score Badge
                    if (hasTelemetry) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(healthMetrics!.healthStatus)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getStatusColor(healthMetrics!.healthStatus)
                                .withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          '${healthMetrics!.overallHealthScore?.round() ?? "--"}% ${healthMetrics!.healthStatus}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(healthMetrics!.healthStatus),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],

                    // Arrow Icon
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: AppColors.background,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.secondaryText,
                        size: 18,
                      ),
                    ),
                  ],
                ),

                // Prompt to view individual sensor readings
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlueLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primaryBlue.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.sensors_rounded,
                            size: 15,
                            color: AppColors.primaryBlue,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Live Sensor Telemetry',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            'View Readings',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: AppColors.primaryBlue,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Stored Sensor Metrics Row: Temperature, Vibration, Sound
                if (hasTelemetry) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderColor, width: 0.8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSensorMetricItem(
                          icon: Icons.thermostat_rounded,
                          label: 'Temp',
                          value: '${healthMetrics!.averageTemperature}°C',
                          color: healthMetrics!.averageTemperature > 60
                              ? AppColors.warning
                              : AppColors.primaryBlue,
                        ),
                        Container(
                          width: 1,
                          height: 18,
                          color: AppColors.borderColor,
                        ),
                        _buildSensorMetricItem(
                          icon: Icons.vibration_rounded,
                          label: 'Vibration',
                          value: '${healthMetrics!.averageVibration}',
                          color: healthMetrics!.averageVibration > 0.4
                              ? AppColors.warning
                              : const Color(0xFF7C3AED),
                        ),
                        Container(
                          width: 1,
                          height: 18,
                          color: AppColors.borderColor,
                        ),
                        _buildSensorMetricItem(
                          icon: Icons.volume_up_rounded,
                          label: 'Sound',
                          value: '${healthMetrics!.averageSound.round()} dB',
                          color: healthMetrics!.averageSound > 60
                              ? AppColors.warning
                              : const Color(0xFF0D9488),
                        ),
                      ],
                    ),
                  ),
                ] else if (latestAnalysis != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        latestAnalysis!.healthCondition,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSensorMetricItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.secondaryText,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
