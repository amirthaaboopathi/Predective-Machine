import 'package:flutter/material.dart';
import '../../models/appliance_model.dart';
import '../../services/auth_service.dart';
import '../../services/appliance_service.dart';
import '../../services/analysis_service.dart';
import '../../services/sensor_service.dart';
import '../../services/hardware_serial_service.dart';
import '../../services/hardware_mapping_service.dart';
import '../../services/alert_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_text_styles.dart';
import '../../widgets/appliance_card.dart';
import '../../widgets/empty_state.dart';
import '../chat/chatbot_screen.dart';

/// Commercial-grade Home Dashboard for Smart Appliance Monitoring.
/// Displays real-time temperature, vibration, and sound telemetry, overall operating condition,
/// and instant navigation to analytics, results, and alerts.
class HomeScreen extends StatefulWidget {
  final VoidCallback onNavigateToAddAppliance;
  final ValueChanged<int>? onNavigateToTab;

  const HomeScreen({
    super.key,
    required this.onNavigateToAddAppliance,
    this.onNavigateToTab,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _hardwareService = HardwareSerialService();
  final _mappingService = HardwareMappingService();
  final _sensorService = SensorService();
  final _applianceService = ApplianceService();
  final _alertService = AlertService();

  String _searchQuery = '';
  String? _selectedApplianceId;

  @override
  void initState() {
    super.initState();
    _applianceService.fetchAppliances();
    _sensorService.fetchAllSensorReadings();
    _mappingService.init();

    // Auto-connect to monitoring hardware on COM3 if not already active
    if (!_hardwareService.isActive) {
      _hardwareService.connect('COM3');
    }

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _openChatbot(BuildContext context, [ApplianceModel? appliance]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.85,
            child: ChatbotScreen(initialAppliance: appliance),
          ),
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final analysisService = AnalysisService();
    final user = authService.currentUser;
    final userName = user?.displayName ?? 'Homeowner';

    return ListenableBuilder(
      listenable: Listenable.merge([
        _applianceService,
        analysisService,
        _sensorService,
        _hardwareService,
        _mappingService,
        _alertService,
      ]),
      builder: (context, _) {
        final allAppliances = _applianceService.appliances;

        // Active Appliance to display
        ApplianceModel? primaryAppliance;
        if (allAppliances.isNotEmpty) {
          primaryAppliance = allAppliances.firstWhere(
            (a) => a.id == _selectedApplianceId,
            orElse: () => allAppliances.first,
          );
        }

        // Strict physical USB connection requirement:
        // Only display sensor values if ESP32 is physically connected via USB to laptop.
        final isUsbConnected = _hardwareService.isConnected && _hardwareService.latestTelemetry != null;
        final liveTelemetry = isUsbConnected ? _hardwareService.latestTelemetry : null;
        final isHardwareLive = isUsbConnected;

        // When disconnected from USB, values are strictly null so UI displays '--' and 'ESP32 Disconnected'
        final double? effectiveTemp = isUsbConnected ? liveTelemetry?.temperature : null;
        final double? effectiveVib = isUsbConnected ? liveTelemetry?.vibrationMagnitude : null;
        final double? effectiveSound = isUsbConnected ? liveTelemetry?.soundDb : null;
        final DateTime? lastUpdateTime = isUsbConnected ? liveTelemetry?.receivedAt : null;

        // Feed to AlertService only if USB is actively connected and streaming data
        if (primaryAppliance != null && liveTelemetry != null) {
          _alertService.evaluateLiveTelemetry(primaryAppliance);
        }

        final filteredAppliances = allAppliances.where((appliance) {
          if (_searchQuery.isEmpty) return true;
          return appliance.name.toLowerCase().contains(_searchQuery) ||
              appliance.type.toLowerCase().contains(_searchQuery) ||
              (appliance.brand?.toLowerCase().contains(_searchQuery) ?? false);
        }).toList();

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Stack(
              children: [
                RefreshIndicator(
                  color: AppColors.primaryBlue,
                  onRefresh: () async {
                    await Future.wait([
                      _applianceService.fetchAppliances(),
                      _sensorService.fetchAllSensorReadings(),
                    ]);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),

                        // 1. HEADER ROW: Branding, Greeting, Device chip, Alerts
                        _buildHeader(userName, isHardwareLive, primaryAppliance),
                        const SizedBox(height: 16),

                        // 2. APPLIANCE SELECTOR (if multiple appliances exist)
                        if (allAppliances.length > 1) ...[
                          _buildApplianceSelector(allAppliances, primaryAppliance?.id),
                          const SizedBox(height: 16),
                        ],

                        // 3. OVERALL APPLIANCE OPERATING CONDITION CARD
                        _buildOverallConditionCard(
                          primaryAppliance,
                          effectiveTemp,
                          effectiveVib,
                          effectiveSound,
                          isHardwareLive,
                          lastUpdateTime,
                        ),
                        const SizedBox(height: 20),

                        // 4. THREE PREMIUM SENSOR MONITORING CARDS
                        Text('Real-Time Parameters', style: AppTextStyles.heading3),
                        const SizedBox(height: 12),
                        _buildSensorCards(
                          effectiveTemp,
                          effectiveVib,
                          effectiveSound,
                          lastUpdateTime,
                        ),
                        const SizedBox(height: 16),

                        // 5. APPLIANCE POWER CONTROL (SMART RELAY)
                        _buildPowerControlCard(isHardwareLive),
                        const SizedBox(height: 20),

                        // 6. QUICK NAVIGATION CARDS (Analytics, Results, Alerts)
                        _buildQuickNavigationRow(),
                        const SizedBox(height: 24),

                        // 7. REGISTERED APPLIANCES FLEET
                        _buildFleetHeader(),
                        const SizedBox(height: 12),
                        _buildAppliancesList(filteredAppliances, analysisService),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),

                // Floating AI Assistant Button
                Positioned(
                  right: 20,
                  bottom: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF246BFD), Color(0xFF6366F1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF246BFD).withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: FloatingActionButton.extended(
                      heroTag: 'home_chatbot_fab',
                      elevation: 0,
                      backgroundColor: Colors.transparent,
                      onPressed: () => _openChatbot(context, primaryAppliance),
                      icon: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: const Text(
                        'AI Assistant',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // SUB-WIDGET BUILDERS
  // ===========================================================================

  Widget _buildHeader(String userName, bool isHardwareLive, ApplianceModel? primaryAppliance) {
    return Row(
      children: [
        // App Icon Avatar
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryBlueLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.shield_outlined,
            color: AppColors.primaryBlue,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),

        // Title and Greeting
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Smart Appliance Monitor',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
              Text(
                '${_getGreeting()}, $userName',
                style: AppTextStyles.heading2.copyWith(fontSize: 18),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // Notifications / Alerts icon
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded, color: AppColors.darkText),
          onPressed: () {
            if (widget.onNavigateToTab != null) {
              widget.onNavigateToTab!(3); // Alerts Tab
            }
          },
        ),
      ],
    );
  }

  Widget _buildApplianceSelector(List<ApplianceModel> appliances, String? currentId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentId,
          isExpanded: true,
          items: appliances.map((a) {
            return DropdownMenuItem(
              value: a.id,
              child: Row(
                children: [
                  const Icon(Icons.devices_rounded, size: 18, color: AppColors.primaryBlue),
                  const SizedBox(width: 10),
                  Text(
                    '${a.name} (${a.type})',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedApplianceId = val);
          },
        ),
      ),
    );
  }

  Widget _buildOverallConditionCard(
    ApplianceModel? appliance,
    double? temp,
    double? vib,
    double? sound,
    bool isLive,
    DateTime? lastUpdate,
  ) {
    String conditionText = 'Operating Normally';
    Color conditionColor = const Color(0xFF10B981);
    String conditionSubtitle = 'All parameters are within verified optimal limits.';
    int activeWarnings = 0;

    if (!isLive || (temp == null && vib == null && sound == null)) {
      conditionText = 'ESP32 Disconnected';
      conditionColor = Colors.blueGrey;
      conditionSubtitle = 'Plug your ESP32 into your laptop USB port to stream live sensor readings.';
    } else {
      if (temp != null && temp > 70) activeWarnings++;
      if (vib != null && vib > 0.80) activeWarnings++;
      if (sound != null && sound > 75) activeWarnings++;

      if (activeWarnings > 0) {
        conditionText = 'Abnormal Condition Detected';
        conditionColor = const Color(0xFFEF4444);
        conditionSubtitle = '$activeWarnings parameter(s) exceed safe operating limits.';
      } else if ((temp != null && temp > 55) || (vib != null && vib > 0.40) || (sound != null && sound > 62)) {
        conditionText = 'Attention Required';
        conditionColor = const Color(0xFFF59E0B);
        conditionSubtitle = 'Elevated operating telemetry detected. Inspection recommended.';
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: conditionColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: conditionColor.withValues(alpha: 0.08),
            blurRadius: 18,
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
                appliance != null ? appliance.name : 'Selected Appliance',
                style: AppTextStyles.caption.copyWith(color: AppColors.secondaryText),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: conditionColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  conditionText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: conditionColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            conditionText,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: conditionColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            conditionSubtitle,
            style: AppTextStyles.bodyMedium,
          ),
          if (lastUpdate != null) ...[
            const SizedBox(height: 10),
            Text(
              'Updated ${_formatTimeAgo(lastUpdate)}',
              style: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSensorCards(double? temp, double? vib, double? sound, DateTime? timestamp) {
    return Column(
      children: [
        // 1. TEMPERATURE CARD
        _buildMetricCard(
          label: 'Appliance Temperature',
          value: temp != null ? '$temp' : '--',
          unit: '°C',
          icon: Icons.thermostat_rounded,
          color: const Color(0xFF0284C7),
          status: temp == null
              ? 'Disconnected'
              : (temp <= 55 ? 'Normal' : (temp <= 70 ? 'Warning' : 'Critical')),
          statusColor: temp == null
              ? Colors.grey
              : (temp <= 55 ? const Color(0xFF10B981) : (temp <= 70 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444))),
          trendIcon: Icons.trending_flat_rounded,
          trendLabel: temp == null ? 'No Signal' : 'Stable',
        ),
        const SizedBox(height: 12),

        // 2. VIBRATION CARD
        _buildMetricCard(
          label: 'Appliance Vibration',
          value: vib != null ? '$vib' : '--',
          unit: 'G',
          icon: Icons.vibration_rounded,
          color: const Color(0xFF7C3AED),
          status: vib == null
              ? 'Disconnected'
              : (vib <= 0.40 ? 'Normal' : (vib <= 0.80 ? 'Warning' : 'Critical')),
          statusColor: vib == null
              ? Colors.grey
              : (vib <= 0.40 ? const Color(0xFF10B981) : (vib <= 0.80 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444))),
          trendIcon: Icons.trending_flat_rounded,
          trendLabel: vib == null ? 'No Signal' : 'Smooth',
        ),
        const SizedBox(height: 12),

        // 3. SOUND CARD
        _buildMetricCard(
          label: 'Operating Sound Level',
          value: sound != null ? '${sound.round()}' : '--',
          unit: 'dB',
          icon: Icons.graphic_eq_rounded,
          color: const Color(0xFF0D9488),
          status: sound == null
              ? 'Disconnected'
              : (sound <= 60 ? 'Normal' : (sound <= 75 ? 'Warning' : 'Critical')),
          statusColor: sound == null
              ? Colors.grey
              : (sound <= 60 ? const Color(0xFF10B981) : (sound <= 75 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444))),
          trendIcon: Icons.trending_flat_rounded,
          trendLabel: sound == null ? 'No Signal' : 'Quiet',
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    required String status,
    required Color statusColor,
    required IconData trendIcon,
    required String trendLabel,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.heading3.copyWith(fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        trendLabel,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPowerControlCard(bool isLive) {
    final relayOn = _hardwareService.relayState;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
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
                  Text(
                    'Appliance Power Control',
                    style: AppTextStyles.heading3.copyWith(fontSize: 14),
                  ),
                  Text(
                    relayOn ? 'Power active • Relay energized' : 'Standby • Power off',
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
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

  Widget _buildQuickNavigationRow() {
    return Row(
      children: [
        Expanded(
          child: _buildNavCard(
            title: 'Analytics',
            subtitle: 'Trends & Stats',
            icon: Icons.bar_chart_rounded,
            color: const Color(0xFF246BFD),
            tabIndex: 1,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildNavCard(
            title: 'Results',
            subtitle: 'Assessments',
            icon: Icons.assignment_rounded,
            color: const Color(0xFF8B5CF6),
            tabIndex: 2,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildNavCard(
            title: 'Alerts',
            subtitle: 'Notifications',
            icon: Icons.notifications_active_rounded,
            color: const Color(0xFFF59E0B),
            tabIndex: 3,
          ),
        ),
      ],
    );
  }

  Widget _buildNavCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required int tabIndex,
  }) {
    return InkWell(
      onTap: () {
        if (widget.onNavigateToTab != null) {
          widget.onNavigateToTab!(tabIndex);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
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
      ),
    );
  }

  Widget _buildFleetHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Monitored Appliances', style: AppTextStyles.heading3),
        TextButton.icon(
          onPressed: widget.onNavigateToAddAppliance,
          icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
          label: const Text('Add Appliance'),
        ),
      ],
    );
  }

  Widget _buildAppliancesList(List<ApplianceModel> appliances, AnalysisService analysisService) {
    if (appliances.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.kitchen_outlined,
        title: 'No appliances registered yet',
        subtitle: 'Add your home appliances to begin continuous telemetry monitoring.',
        buttonText: 'Add Appliance',
        onButtonPressed: widget.onNavigateToAddAppliance,
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: appliances.length,
      itemBuilder: (context, index) {
        final appliance = appliances[index];
        final latestAnalysis = analysisService.getLatestAnalysisForAppliance(appliance.id);
        final healthMetrics = _sensorService.getHealthMetricsForAppliance(appliance.id, appliance.name);
        final latestReading = _sensorService.getLatestReadingForAppliance(appliance.id, appliance.name);

        return ApplianceCard(
          appliance: appliance,
          latestAnalysis: latestAnalysis,
          healthMetrics: healthMetrics,
          latestReading: latestReading,
          onTap: () {
            Navigator.pushNamed(
              context,
              '/sensor-status',
              arguments: appliance,
            );
          },
        );
      },
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
