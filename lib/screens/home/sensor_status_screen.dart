import 'package:flutter/material.dart';
import '../../models/appliance_model.dart';
import '../../services/sensor_service.dart';
import '../../services/hardware_serial_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_text_styles.dart';

/// Screen displaying ONLY the individual real-time sensor readings for a selected appliance.
/// Focuses purely on Temperature, Vibration, and Sound telemetry with verified units and statuses.
class SensorStatusScreen extends StatefulWidget {
  final ApplianceModel appliance;

  const SensorStatusScreen({
    super.key,
    required this.appliance,
  });

  @override
  State<SensorStatusScreen> createState() => _SensorStatusScreenState();
}

class _SensorStatusScreenState extends State<SensorStatusScreen> {
  final _sensorService = SensorService();
  final _hardwareService = HardwareSerialService();

  @override
  void initState() {
    super.initState();
    _sensorService.fetchSensorReadings(widget.appliance.id);
    // Ensure live telemetry generation and streaming starts for this machine when clicked
    _sensorService.ensureLiveTelemetryForAppliance(widget.appliance);
  }

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

  String _formatTime(DateTime? dt) {
    if (dt == null) return 'No timestamp';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_sensorService, _hardwareService]),
      builder: (context, _) {
        // Retrieve readings for this appliance
        final readings = _sensorService.getReadingsForAppliance(
          widget.appliance.id,
          widget.appliance.name,
        );
        final latestStored = readings.isNotEmpty ? readings.first : null;

        // If hardware is active on this port (or fallback if single device)
        final liveTelemetry = _hardwareService.isActive ? _hardwareService.latestTelemetry : null;

        // Current sensor values (live stream takes precedence)
        final temp = liveTelemetry?.temperature ?? latestStored?.temperature ?? 28.0;
        final vib = liveTelemetry?.vibrationMagnitude ?? latestStored?.vibration ?? 0.16;
        final sound = liveTelemetry?.soundDb ?? latestStored?.sound ?? 48.0;
        final lastUpdate = liveTelemetry?.receivedAt ?? latestStored?.recordedAt ?? DateTime.now();
        final relayOn = _hardwareService.relayState;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Sensor Status'),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh Telemetry',
                onPressed: () {
                  _sensorService.fetchSensorReadings(widget.appliance.id);
                  _sensorService.ensureLiveTelemetryForAppliance(widget.appliance);
                },
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Appliance Header Card
                  _buildApplianceHeader(relayOn),
                  const SizedBox(height: 20),

                  // Power Relay Control for this appliance
                  _buildRelayControlCard(relayOn),
                  const SizedBox(height: 24),

                  // Section Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Individual Sensor Readings',
                            style: AppTextStyles.heading2.copyWith(fontSize: 18),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Real-time physical telemetry parameters',
                            style: AppTextStyles.caption.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'STREAMING',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF047857),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 1. TEMPERATURE SENSOR CARD
                  _buildSensorCard(
                    title: 'Appliance Temperature',
                    value: '${temp.toStringAsFixed(1)} °C',
                    icon: Icons.thermostat_rounded,
                    accentColor: const Color(0xFF0284C7),
                    status: temp <= 55.0 ? 'Optimal' : (temp <= 70.0 ? 'Elevated' : 'Critical'),
                    referenceRange: '20.0 °C - 55.0 °C',
                    timestamp: lastUpdate,
                    progress: (temp / 100.0).clamp(0.0, 1.0),
                    diagnosticNote: temp <= 55.0
                        ? 'Thermal dissipation is within manufacturer design limits.'
                        : 'Elevated thermal readings detected. Inspect cooling vents.',
                  ),
                  const SizedBox(height: 16),

                  // 2. VIBRATION SENSOR CARD
                  _buildSensorCard(
                    title: 'Appliance Vibration',
                    value: '${vib.toStringAsFixed(2)} G',
                    icon: Icons.vibration_rounded,
                    accentColor: const Color(0xFF7C3AED),
                    status: vib <= 0.40 ? 'Optimal' : (vib <= 0.80 ? 'Elevated' : 'Critical'),
                    referenceRange: '0.10 G - 0.40 G',
                    timestamp: lastUpdate,
                    progress: (vib / 1.5).clamp(0.0, 1.0),
                    diagnosticNote: vib <= 0.40
                        ? 'Stable rotor balance without abnormal harmonic oscillations.'
                        : 'Vibration exceeds baseline. Check appliance leveling & mounting.',
                  ),
                  const SizedBox(height: 16),

                  // 3. SOUND SENSOR CARD
                  _buildSensorCard(
                    title: 'Operating Sound Level',
                    value: '${sound.round()} dB',
                    icon: Icons.graphic_eq_rounded,
                    accentColor: const Color(0xFF0D9488),
                    status: sound <= 62.0 ? 'Optimal' : (sound <= 75.0 ? 'Elevated' : 'Critical'),
                    referenceRange: '30 dB - 62 dB',
                    timestamp: lastUpdate,
                    progress: (sound / 100.0).clamp(0.0, 1.0),
                    diagnosticNote: sound <= 62.0
                        ? 'Acoustic emissions are nominal without bearing noise or grinding.'
                        : 'High acoustic noise detected. Inspect compressor or drive motor.',
                  ),
                  const SizedBox(height: 24),

                  // Machine Health Card
                  _buildSummaryCard(temp, vib, sound),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildApplianceHeader(bool relayOn) {
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
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primaryBlueLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _getApplianceIcon(widget.appliance.type),
              color: AppColors.primaryBlue,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.appliance.name,
                  style: AppTextStyles.heading2.copyWith(fontSize: 18),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.appliance.brand != null && widget.appliance.brand!.isNotEmpty
                      ? '${widget.appliance.brand} • ${widget.appliance.type}'
                      : widget.appliance.type,
                  style: AppTextStyles.caption.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: relayOn
                  ? const Color(0xFF10B981).withValues(alpha: 0.12)
                  : Colors.grey.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              relayOn ? 'POWER ON' : 'STANDBY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: relayOn ? const Color(0xFF047857) : Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelayControlCard(bool relayOn) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: relayOn
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.power_settings_new_rounded,
                  color: relayOn ? const Color(0xFF10B981) : Colors.grey[600],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Appliance Power Control',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    relayOn ? 'Smart Relay active • Machine running' : 'Power cut • Relay de-energized',
                    style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                  ),
                ],
              ),
            ],
          ),
          Switch(
            value: relayOn,
            activeThumbColor: const Color(0xFF10B981),
            onChanged: (val) {
              _hardwareService.setRelay(val);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(val ? 'Appliance power switched ON' : 'Appliance power switched OFF'),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSensorCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    required String status,
    required String referenceRange,
    required DateTime timestamp,
    required double progress,
    required String diagnosticNote,
  }) {
    Color statusColor;
    if (status == 'Optimal') {
      statusColor = const Color(0xFF10B981);
    } else if (status == 'Elevated') {
      statusColor = const Color(0xFFF59E0B);
    } else {
      statusColor = const Color(0xFFEF4444);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accentColor.withValues(alpha: 0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Icon + Title and Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accentColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: AppTextStyles.heading3.copyWith(fontSize: 15),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Primary Value Display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                  letterSpacing: -0.5,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Text(
                  'Normal: $referenceRange',
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Level Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          const SizedBox(height: 12),

          // Micro-diagnostic Note
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    diagnosticNote,
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Timestamp Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.access_time_rounded, size: 12, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                'Updated at ${_formatTime(timestamp)}',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(double temp, double vib, double sound) {
    final isNormal = temp <= 55 && vib <= 0.40 && sound <= 62;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isNormal ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isNormal ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFFF59E0B).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isNormal ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            color: isNormal ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isNormal ? 'Operating within Verified Limits' : 'Attention Recommended',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isNormal ? const Color(0xFF065F46) : const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isNormal
                      ? 'All thermal, vibration, and acoustic telemetry points are healthy.'
                      : 'One or more sensor parameters are nearing alert thresholds.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isNormal ? const Color(0xFF047857) : const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
