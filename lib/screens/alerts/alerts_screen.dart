import 'package:flutter/material.dart';
import '../../models/appliance_alert_model.dart';
import '../../services/alert_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_text_styles.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _alertService = AlertService();
  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All',
    'Temperature',
    'Vibration',
    'Sound',
    'Warning',
    'Critical',
  ];

  Color _getSeverityColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return const Color(0xFFEF4444);
      case AlertSeverity.warning:
        return const Color(0xFFF59E0B);
      case AlertSeverity.normal:
        return const Color(0xFF10B981);
      case AlertSeverity.offline:
        return Colors.grey;
    }
  }

  IconData _getParameterIcon(AlertParameter param) {
    switch (param) {
      case AlertParameter.temperature:
        return Icons.thermostat_rounded;
      case AlertParameter.vibration:
        return Icons.vibration_rounded;
      case AlertParameter.sound:
        return Icons.graphic_eq_rounded;
      case AlertParameter.connectivity:
        return Icons.wifi_off_rounded;
      case AlertParameter.general:
        return Icons.info_outline_rounded;
    }
  }

  List<ApplianceAlertModel> _filterAlerts(List<ApplianceAlertModel> alerts) {
    switch (_selectedFilter) {
      case 'Temperature':
        return alerts.where((a) => a.parameter == AlertParameter.temperature).toList();
      case 'Vibration':
        return alerts.where((a) => a.parameter == AlertParameter.vibration).toList();
      case 'Sound':
        return alerts.where((a) => a.parameter == AlertParameter.sound).toList();
      case 'Warning':
        return alerts.where((a) => a.severity == AlertSeverity.warning).toList();
      case 'Critical':
        return alerts.where((a) => a.severity == AlertSeverity.critical).toList();
      default:
        return alerts;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _alertService,
      builder: (context, _) {
        final allAlerts = _alertService.allAlerts;
        final filteredAlerts = _filterAlerts(allAlerts);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Operating Alerts'),
            automaticallyImplyLeading: false,
            actions: [
              if (allAlerts.any((a) => !a.isAcknowledged))
                TextButton(
                  onPressed: () {
                    _alertService.acknowledgeAll();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All alerts marked as acknowledged'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('Acknowledge All'),
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filter chips
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filter = _filters[index];
                      final isSelected = _selectedFilter == filter;

                      return ChoiceChip(
                        label: Text(filter),
                        selected: isSelected,
                        selectedColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                        backgroundColor: AppColors.surface,
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? AppColors.primaryBlue : AppColors.secondaryText,
                        ),
                        side: BorderSide(
                          color: isSelected ? AppColors.primaryBlue : AppColors.borderColor,
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        onSelected: (_) => setState(() => _selectedFilter = filter),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // Alerts list
                Expanded(
                  child: filteredAlerts.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEFF6FF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.verified_user_outlined,
                                    size: 48,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'All Systems Normal',
                                  style: AppTextStyles.heading2.copyWith(fontSize: 18),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _selectedFilter == 'All'
                                      ? 'No active warnings or abnormal conditions recorded.'
                                      : 'No alerts found in the "$_selectedFilter" category.',
                                  style: AppTextStyles.subtitle,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredAlerts.length,
                          itemBuilder: (context, index) {
                            final alert = filteredAlerts[index];
                            final sevColor = _getSeverityColor(alert.severity);
                            final paramIcon = _getParameterIcon(alert.parameter);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: alert.isAcknowledged
                                      ? AppColors.borderColor
                                      : sevColor.withValues(alpha: 0.4),
                                  width: alert.isAcknowledged ? 1.0 : 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: alert.isAcknowledged
                                        ? AppColors.shadowColor
                                        : sevColor.withValues(alpha: 0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: sevColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(paramIcon, color: sevColor, size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      alert.title,
                                                      style: AppTextStyles.heading3.copyWith(
                                                        fontSize: 15,
                                                        color: alert.isAcknowledged
                                                            ? AppColors.secondaryText
                                                            : AppColors.darkText,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: sevColor.withValues(alpha: 0.12),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      alert.severity.name.toUpperCase(),
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: sevColor,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${alert.applianceName} • ${_formatDateTime(alert.timestamp)}',
                                                style: AppTextStyles.caption.copyWith(fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      alert.description,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontSize: 13,
                                        color: alert.isAcknowledged
                                            ? AppColors.secondaryText
                                            : AppColors.darkText,
                                      ),
                                    ),
                                    if (alert.recordedValue != null) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.background,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Recorded Reading: ${alert.recordedValue} ${alert.unit ?? ""}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: sevColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (!alert.isAcknowledged) ...[
                                      const SizedBox(height: 10),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          onPressed: () {
                                            _alertService.acknowledgeAlert(alert.id);
                                          },
                                          icon: const Icon(Icons.check_rounded, size: 16),
                                          label: const Text('Acknowledge'),
                                          style: TextButton.styleFrom(
                                            foregroundColor: AppColors.primaryBlue,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }
}
