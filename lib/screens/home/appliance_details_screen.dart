import 'package:flutter/material.dart';
import '../../models/appliance_model.dart';
import '../../models/hardware_telemetry_model.dart';
import '../../services/analysis_service.dart';
import '../../services/sensor_service.dart';
import '../../services/hardware_serial_service.dart';
import '../../services/hardware_mapping_service.dart';
import '../../services/appliance_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_text_styles.dart';
import '../../widgets/primary_button.dart';

/// Screen displaying detailed appliance info, live hardware sensor telemetry (COM3),
/// interactive relay control, cloud database recording, and diagnostic health triggers.
class ApplianceDetailsScreen extends StatefulWidget {
  final ApplianceModel appliance;

  const ApplianceDetailsScreen({
    super.key,
    required this.appliance,
  });

  @override
  State<ApplianceDetailsScreen> createState() => _ApplianceDetailsScreenState();
}

class _ApplianceDetailsScreenState extends State<ApplianceDetailsScreen> {
  final _sensorService = SensorService();
  final _hardwareService = HardwareSerialService();
  final _mappingService = HardwareMappingService();

  late ApplianceModel _currentAppliance;
  bool _isSavingSnapshot = false;

  @override
  void initState() {
    super.initState();
    _currentAppliance = widget.appliance;
    _initData();
  }

  Future<void> _initData() async {
    await _mappingService.init();
    final assignedPort = _mappingService.getPortForAppliance(_currentAppliance.id);
    if (assignedPort != null) {
      setState(() {
        _currentAppliance = _currentAppliance.copyWith(hardwarePort: assignedPort);
      });
    }

    try {
      await _sensorService.fetchSensorReadings(_currentAppliance.id);
    } catch (_) {}
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

  // Opens the hardware link & port management dialog
  void _openHardwareConfigDialog() {
    String selectedPort = _currentAppliance.hardwarePort ?? 'COM3';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.settings_input_composite_rounded,
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
                                'Hardware Sensor Link',
                                style: AppTextStyles.heading2.copyWith(fontSize: 18),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Assign physical COM port for "${_currentAppliance.name}"',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: AppColors.dividerColor),
                    const SizedBox(height: 16),

                    Text('Designated COM Port', style: AppTextStyles.label),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedPort,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: 'COM3',
                              child: Text('COM3 (Primary Sensor Unit)'),
                            ),
                            DropdownMenuItem(
                              value: 'COM4',
                              child: Text('COM4 (Secondary Device)'),
                            ),
                            DropdownMenuItem(
                              value: 'None',
                              child: Text('None (Unassigned)'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setSheetState(() => selectedPort = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_outlined, size: 20, color: AppColors.primaryBlue),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Rule: Only ONE appliance can receive telemetry from $selectedPort. Multiple appliances require multiple dedicated devices.',
                              style: AppTextStyles.caption.copyWith(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Connection Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _hardwareService.startSimulation();
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Simulated Hardware stream started for testing.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                            label: const Text('Test Stream'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final portToSet = selectedPort == 'None' ? null : selectedPort;
                              await ApplianceService().setApplianceHardwarePort(
                                _currentAppliance.id,
                                portToSet,
                              );
                              setState(() {
                                _currentAppliance =
                                    _currentAppliance.copyWith(hardwarePort: portToSet);
                              });

                              if (portToSet != null) {
                                _hardwareService.setActivePort(portToSet);
                                await _hardwareService.connect();
                              }

                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      portToSet != null
                                          ? 'Linked to $portToSet! Stream active.'
                                          : 'Hardware unlinked.',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                            label: const Text(
                              'Save Link',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Manually captures and records the current live reading into Supabase
  Future<void> _recordManualSnapshot() async {
    final telemetry = _hardwareService.latestTelemetry;
    if (telemetry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No telemetry stream available to capture yet. Connect hardware or click Test Stream.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSavingSnapshot = true);
    try {
      await _sensorService.recordSensorReading(
        applianceId: _currentAppliance.id,
        applianceName: _currentAppliance.name,
        temperature: telemetry.temperature,
        vibration: telemetry.vibrationMagnitude,
        sound: telemetry.soundDb,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recorded to Supabase: ${telemetry.temperature}°C, Vib ${telemetry.vibrationMagnitude}, ${telemetry.soundDb} dB',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save to Supabase: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingSnapshot = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final analysisService = AnalysisService();

    return ListenableBuilder(
      listenable: Listenable.merge([
        analysisService,
        _sensorService,
        _hardwareService,
        _mappingService,
      ]),
      builder: (context, _) {
        final latestAnalysis =
            analysisService.getLatestAnalysisForAppliance(_currentAppliance.id);
        final metrics = _sensorService.getHealthMetricsForAppliance(
          _currentAppliance.id,
          _currentAppliance.name,
        );
        final isLoadingSensors = _sensorService.isLoading(_currentAppliance.id);

        final isHardwareBound = _currentAppliance.isHardwareMonitored;
        final boundPort = _currentAppliance.hardwarePort ?? 'COM3';
        final isPortMatch = _hardwareService.activePort == boundPort;
        final isHardwareLive = isHardwareBound && _hardwareService.isActive && isPortMatch;
        final liveTelemetry = isHardwareLive ? _hardwareService.latestTelemetry : null;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Appliance Telemetry'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                tooltip: 'Hardware Settings',
                icon: const Icon(
                  Icons.sensors_rounded,
                  color: AppColors.primaryBlue,
                ),
                onPressed: _openHardwareConfigDialog,
              ),
              IconButton(
                tooltip: 'Ask AI Assistant',
                icon: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primaryBlue,
                ),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/chatbot',
                    arguments: _currentAppliance,
                  );
                },
              ),
            ],
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await _sensorService.fetchSensorReadings(_currentAppliance.id);
              },
              color: AppColors.primaryBlue,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // =========================================================
                    // 1. HERO APPLIANCE CARD
                    // =========================================================
                    _buildHeroApplianceCard(isHardwareLive, boundPort),
                    const SizedBox(height: 16),

                    // =========================================================
                    // 2. HARDWARE DEVICE CONNECTION & CONTROL BANNER
                    // =========================================================
                    _buildHardwareConnectionBanner(isHardwareBound, boundPort, isHardwareLive),
                    const SizedBox(height: 20),

                    // =========================================================
                    // 3. LIVE SENSOR TELEMETRY GAUGES (MPU6050, DS18B20, INMP441)
                    // =========================================================
                    Text(
                      isHardwareLive
                          ? 'Real-Time Hardware Stream ($boundPort)'
                          : 'Appliance Health & Telemetry',
                      style: AppTextStyles.heading3,
                    ),
                    const SizedBox(height: 12),

                    if (isHardwareLive && liveTelemetry != null) ...[
                      // LIVE TELEMETRY CARDS
                      _buildLiveTelemetryGrid(liveTelemetry),
                      const SizedBox(height: 16),

                      // HARDWARE RELAY SWITCH CONTROLLER
                      _buildHardwareRelayCard(),
                      const SizedBox(height: 16),

                      // CLOUD STORAGE & SYNC BAR
                      _buildCloudStorageBar(),
                      const SizedBox(height: 24),
                    ] else ...[
                      // DATABASE AGGREGATED METRICS CARD
                      _buildDatabaseMetricsCard(metrics, isLoadingSensors),
                      const SizedBox(height: 24),
                    ],

                    // =========================================================
                    // 4. APPLIANCE TECHNICAL SPECIFICATIONS
                    // =========================================================
                    Text(
                      'Appliance Specifications',
                      style: AppTextStyles.heading3,
                    ),
                    const SizedBox(height: 12),
                    _buildSpecificationsCard(boundPort),
                    const SizedBox(height: 24),

                    // =========================================================
                    // 5. DIAGNOSTIC SCAN & REPORT
                    // =========================================================
                    Text(
                      'Diagnostic Intelligence',
                      style: AppTextStyles.heading3,
                    ),
                    const SizedBox(height: 12),
                    _buildDiagnosticReportCard(latestAnalysis),
                    const SizedBox(height: 28),

                    // =========================================================
                    // 6. ACTION BUTTONS (AI & HEALTH CHECK)
                    // =========================================================
                    _buildActionButtons(),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // WIDGET BUILDERS
  // ===========================================================================

  Widget _buildHeroApplianceCard(bool isHardwareLive, String boundPort) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isHardwareLive
              ? AppColors.primaryBlue.withValues(alpha: 0.4)
              : AppColors.borderColor,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isHardwareLive
                  ? const Color(0xFFEFF6FF)
                  : AppColors.lightBlue,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              _getApplianceIcon(_currentAppliance.type),
              size: 34,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _currentAppliance.name,
                        style: AppTextStyles.heading2.copyWith(fontSize: 18),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_currentAppliance.isHardwareMonitored) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isHardwareLive
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : Colors.grey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          boundPort,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isHardwareLive
                                ? const Color(0xFF047857)
                                : AppColors.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _currentAppliance.brand != null && _currentAppliance.brand!.isNotEmpty
                      ? '${_currentAppliance.brand} • ${_currentAppliance.type}'
                      : _currentAppliance.type,
                  style: AppTextStyles.subtitle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareConnectionBanner(
    bool isHardwareBound,
    String boundPort,
    bool isHardwareLive,
  ) {
    if (!isHardwareBound) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.link_off_rounded, color: Colors.blueGrey, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'No Hardware Device Linked',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Assign COM3 to stream real-time MPU6050, DS18B20 & mic telemetry.',
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _openHardwareConfigDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: const Text('Link COM3', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (_hardwareService.status) {
      case HardwareConnectionStatus.connected:
        statusColor = const Color(0xFF10B981);
        statusText = 'Connected to $boundPort (Active)';
        statusIcon = Icons.check_circle_rounded;
        break;
      case HardwareConnectionStatus.simulated:
        statusColor = const Color(0xFF8B5CF6);
        statusText = 'Simulated Stream Active ($boundPort)';
        statusIcon = Icons.stream_rounded;
        break;
      case HardwareConnectionStatus.connecting:
        statusColor = const Color(0xFFF59E0B);
        statusText = 'Connecting to $boundPort...';
        statusIcon = Icons.sync_rounded;
        break;
      case HardwareConnectionStatus.error:
      case HardwareConnectionStatus.disconnected:
        statusColor = const Color(0xFFEF4444);
        statusText = '$boundPort Disconnected (Ready to Connect)';
        statusIcon = Icons.power_off_rounded;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: statusColor,
                  ),
                ),
                Text(
                  isHardwareLive
                      ? 'Packets: ${_hardwareService.totalPacketsReceived} | 115200 baud'
                      : 'Plug in hardware to COM3 and tap Connect.',
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          if (!isHardwareLive) ...[
            TextButton(
              onPressed: () => _hardwareService.connect(boundPort),
              style: TextButton.styleFrom(
                foregroundColor: statusColor,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text('Connect', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.power_settings_new_rounded, size: 20),
              color: statusColor,
              tooltip: 'Disconnect',
              onPressed: () => _hardwareService.disconnect(),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. LIVE SENSOR GAUGES (Temperature, Vibration, Sound)
  // ===========================================================================

  Widget _buildLiveTelemetryGrid(HardwareTelemetryModel telemetry) {
    return Column(
      children: [
        // Live Temperature Card (DS18B20 + MPU6050)
        _buildTelemetryMetricCard(
          title: 'Core Temperature',
          value: '${telemetry.temperature} °C',
          sensorName: telemetry.dsConnected ? 'DS18B20 Digital Probe' : 'MPU6050 Onboard',
          icon: Icons.thermostat_rounded,
          accentColor: telemetry.temperature > 65
              ? const Color(0xFFEF4444)
              : (telemetry.temperature > 50 ? const Color(0xFFF59E0B) : const Color(0xFF06B6D4)),
          subtitle: 'Optimal range: 20°C - 55°C',
          indicatorLevel: (telemetry.temperature / 100.0).clamp(0.0, 1.0),
        ),
        const SizedBox(height: 12),

        // Live Vibration Card (MPU6050 3-Axis Accel & Gyro)
        _buildTelemetryMetricCard(
          title: 'Vibration & Mechanical Stability',
          value: '${telemetry.vibrationMagnitude} G',
          sensorName: 'MPU6050 6-Axis Motion Sensor',
          icon: Icons.vibration_rounded,
          accentColor: telemetry.vibrationMagnitude > 0.50
              ? const Color(0xFFEF4444)
              : const Color(0xFF8B5CF6),
          subtitle: 'Ax: ${telemetry.ax.toStringAsFixed(2)} | Ay: ${telemetry.ay.toStringAsFixed(2)} | Az: ${telemetry.az.toStringAsFixed(2)}',
          indicatorLevel: (telemetry.vibrationMagnitude / 1.5).clamp(0.0, 1.0),
        ),
        const SizedBox(height: 12),

        // Live Sound Card (INMP441 Microphone)
        _buildTelemetryMetricCard(
          title: 'Acoustic Sound Level',
          value: '${telemetry.soundDb} dB',
          sensorName: 'INMP441 Digital I2S Microphone',
          icon: Icons.graphic_eq_rounded,
          accentColor: telemetry.soundDb > 70
              ? const Color(0xFFEF4444)
              : const Color(0xFF10B981),
          subtitle: 'RMS: ${telemetry.micRms.toStringAsFixed(1)} | Peak: ${telemetry.micPeak}',
          indicatorLevel: (telemetry.soundDb / 100.0).clamp(0.0, 1.0),
        ),
      ],
    );
  }

  Widget _buildTelemetryMetricCard({
    required String title,
    required String value,
    required String sensorName,
    required IconData icon,
    required Color accentColor,
    required String subtitle,
    required double indicatorLevel,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withValues(alpha: 0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.heading3.copyWith(fontSize: 14)),
                      Text(
                        sensorName,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.secondaryText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: indicatorLevel,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: AppTextStyles.caption.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // HARDWARE RELAY SWITCH CONTROLLER
  // ===========================================================================

  Widget _buildHardwareRelayCard() {
    final isOn = _hardwareService.relayState;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOn
              ? [const Color(0xFF059669).withValues(alpha: 0.08), const Color(0xFF10B981).withValues(alpha: 0.15)]
              : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOn ? const Color(0xFF10B981) : AppColors.borderColor,
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isOn
                      ? const Color(0xFF10B981)
                      : Colors.blueGrey[300],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.power_settings_new_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hardware Relay (Pin 27)',
                    style: AppTextStyles.heading3.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isOn ? 'Status: ACTIVE / ON' : 'Status: STANDBY / OFF',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isOn ? const Color(0xFF047857) : Colors.blueGrey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Switch(
            value: isOn,
            activeThumbColor: const Color(0xFF10B981),
            onChanged: (val) {
              _hardwareService.setRelay(val);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(val ? 'Hardware Relay switched ON' : 'Hardware Relay switched OFF'),
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

  // ===========================================================================
  // CLOUD STORAGE & SNAPSHOT BAR
  // ===========================================================================

  Widget _buildCloudStorageBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.cloud_sync_rounded, color: AppColors.primaryBlue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Auto-Sync to Cloud',
                    style: AppTextStyles.heading3.copyWith(fontSize: 14),
                  ),
                ],
              ),
              Switch(
                value: _hardwareService.autoSyncToCloud,
                activeThumbColor: AppColors.primaryBlue,
                onChanged: (val) {
                  _hardwareService.setAutoSyncToCloud(val);
                },
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sync interval: ${_hardwareService.cloudSyncIntervalSeconds}s',
                style: AppTextStyles.caption,
              ),
              ElevatedButton.icon(
                onPressed: _isSavingSnapshot ? null : _recordManualSnapshot,
                icon: _isSavingSnapshot
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded, size: 16, color: Colors.white),
                label: const Text(
                  'Save Snapshot',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // DATABASE AGGREGATED METRICS CARD (WHEN STREAM IS IDLE)
  // ===========================================================================

  Widget _buildDatabaseMetricsCard(dynamic metrics, bool isLoadingSensors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isLoadingSensors
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primaryBlue),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stored Health Score',
                          style: AppTextStyles.caption.copyWith(color: AppColors.secondaryText),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          metrics.overallHealthScore != null
                              ? '${metrics.overallHealthScore!.round()}%'
                              : 'No Data',
                          style: AppTextStyles.heading1.copyWith(
                            fontSize: 32,
                            color: _getStatusColor(metrics.healthStatus),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _getStatusColor(metrics.healthStatus).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getStatusColor(metrics.healthStatus).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        metrics.healthStatus,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(metrics.healthStatus),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, color: AppColors.dividerColor),
                const SizedBox(height: 16),

                Text(
                  'Average Database Telemetry (${metrics.readingCount} entries)',
                  style: AppTextStyles.heading3.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 12),

                if (metrics.readingCount == 0) ...[
                  Text(
                    'No sensor telemetry stored for this appliance in Supabase yet.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.secondaryText),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      _hardwareService.startSimulation();
                    },
                    icon: const Icon(Icons.sensors_rounded, size: 16),
                    label: const Text('Start Live Hardware Monitor'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryBlue,
                      side: const BorderSide(color: AppColors.primaryBlue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ] else ...[
                  _buildSensorMetricRow(
                    label: 'Avg Temperature',
                    value: '${metrics.averageTemperature} °C',
                    icon: Icons.thermostat_rounded,
                    iconColor: Colors.orange,
                  ),
                  const SizedBox(height: 10),
                  _buildSensorMetricRow(
                    label: 'Avg Vibration',
                    value: '${metrics.averageVibration}',
                    icon: Icons.vibration_rounded,
                    iconColor: Colors.purple,
                  ),
                  const SizedBox(height: 10),
                  _buildSensorMetricRow(
                    label: 'Avg Sound',
                    value: '${metrics.averageSound} dB',
                    icon: Icons.graphic_eq_rounded,
                    iconColor: Colors.blue,
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildSensorMetricRow({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: AppTextStyles.bodyMedium),
          ),
          Text(
            value,
            style: AppTextStyles.heading3.copyWith(fontSize: 15, color: AppColors.darkText),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. SPECIFICATIONS CARD
  // ===========================================================================

  Widget _buildSpecificationsCard(String boundPort) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Column(
        children: [
          _buildInfoRow('Name', _currentAppliance.name),
          const Divider(height: 20, color: AppColors.dividerColor),
          _buildInfoRow('Type', _currentAppliance.type),
          const Divider(height: 20, color: AppColors.dividerColor),
          _buildInfoRow('Brand', _currentAppliance.brand ?? 'Not specified'),
          const Divider(height: 20, color: AppColors.dividerColor),
          _buildInfoRow('Model', _currentAppliance.modelNumber ?? 'Not specified'),
          const Divider(height: 20, color: AppColors.dividerColor),
          _buildInfoRow('Hardware Port', _currentAppliance.isHardwareMonitored ? boundPort : 'None (Unassigned)'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.secondaryText),
        ),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ===========================================================================
  // 5. DIAGNOSTIC REPORT CARD
  // ===========================================================================

  Widget _buildDiagnosticReportCard(dynamic latestAnalysis) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: latestAnalysis == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.secondaryText, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'No diagnostic scan run yet',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.secondaryText),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Run an interactive health check or telemetry diagnostic scan for automated AI analysis.',
                  style: AppTextStyles.caption,
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Condition Evaluation:', style: AppTextStyles.caption),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        latestAnalysis.healthCondition,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/result-screen',
                      arguments: latestAnalysis,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('View Full Analysis Report'),
                ),
              ],
            ),
    );
  }

  // ===========================================================================
  // 6. ACTION BUTTONS
  // ===========================================================================

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Ask AI Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF246BFD), Color(0xFF6366F1)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF246BFD).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/chatbot',
                  arguments: _currentAppliance,
                );
              },
              icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
              label: const Text(
                'Ask AI Assistant About Telemetry',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Start Health Check Button
        PrimaryButton(
          text: 'Start Health Check Questionnaire',
          icon: Icons.health_and_safety_rounded,
          onPressed: () {
            Navigator.pushNamed(
              context,
              '/health-check',
              arguments: _currentAppliance,
            );
          },
        ),
        const SizedBox(height: 12),

        // Diagnostic Telemetry Scan Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/analysis-screen',
                arguments: _currentAppliance,
              );
            },
            icon: const Icon(Icons.search_rounded, color: AppColors.primaryBlue),
            label: const Text(
              'Diagnostic Telemetry Scan',
              style: TextStyle(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ),
      ],
    );
  }
}
