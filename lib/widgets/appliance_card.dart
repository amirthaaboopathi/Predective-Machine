import 'package:flutter/material.dart';
import '../models/appliance_model.dart';
import '../models/analysis_model.dart';
import '../models/appliance_health_metrics.dart';
import '../models/sensor_reading_model.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';

/// Card widget representing an individual appliance on the dashboard.
/// Clean, executive, consumer-facing card with clear health status
/// and direct one-tap navigation to individual sensor readings.
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
      case 'Optimal':
        return const Color(0xFF10B981);
      case 'Average':
      case 'Warning':
      case 'Elevated':
        return const Color(0xFFF59E0B);
      case 'Poor':
      case 'Critical':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF10B981);
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconData = _getApplianceIcon(appliance.type);
    final statusString = healthMetrics?.healthStatus ?? 'Optimal';
    final statusColor = _getStatusColor(statusString);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Icon + Title/Brand + Status Pill + Chevron
                Row(
                  children: [
                    // Appliance Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlueLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        iconData,
                        size: 24,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Appliance Name & Brand
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appliance.name,
                            style: AppTextStyles.heading3.copyWith(fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
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

                    // Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusString,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Prompt to view individual sensor readings
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
                        children: const [
                          Icon(
                            Icons.sensors_rounded,
                            size: 15,
                            color: AppColors.primaryBlue,
                          ),
                          SizedBox(width: 6),
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
                        children: const [
                          Text(
                            'View Readings',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          SizedBox(width: 4),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
