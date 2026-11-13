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

/// Commercial-grade Home Dashboard for Smart Appliance Monitoring.
/// Fast, minimal, professional layout without unnecessary clutter or floating elements.
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
  final _hardwareService = HardwareSerialService();
  final _mappingService = HardwareMappingService();
  final _sensorService = SensorService();
  final _applianceService = ApplianceService();
  final _alertService = AlertService();

  bool _isRegisteringPreset = false;

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
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Future<void> _handleQuickPreset(String name, String type, String brand) async {
    setState(() => _isRegisteringPreset = true);
    try {
      final appliance = await _applianceService.registerPreset(
        name: name,
        type: type,
        brand: brand,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${appliance.name} registered! Tap to view live sensor readings.'),
            backgroundColor: AppColors.primaryBlue,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to register: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRegisteringPreset = false);
    }
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
        final hasAppliances = allAppliances.isNotEmpty;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: RefreshIndicator(
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

                    // 1. HEADER ROW: Clean branding, greeting, alerts bell
                    _buildHeader(userName),
                    const SizedBox(height: 18),

                    // IF NO APPLIANCES ARE REGISTERED: Show Onboarding Hub
                    if (!hasAppliances) ...[
                      _buildOnboardingAddApplianceHero(),
                      const SizedBox(height: 24),
                      _buildQuickPresetsSection(),
                      const SizedBox(height: 24),
                      _buildSensorFeaturesExplanation(),
                      const SizedBox(height: 40),
                    ] else ...[
                      // IF APPLIANCES EXIST: Show Fleet Dashboard
                      _buildFleetOverviewCard(allAppliances.length),
                      const SizedBox(height: 18),

                      // Power Control Card (Smart Relay Pin 27)
                      _buildPowerControlCard(),
                      const SizedBox(height: 20),

                      // Quick Navigation Cards (Analytics, Results, Alerts)
                      _buildQuickNavigationRow(),
                      const SizedBox(height: 24),

                      // Monitored Appliances Fleet
                      _buildFleetHeader(),
                      const SizedBox(height: 12),
                      _buildAppliancesList(allAppliances, analysisService),
                      const SizedBox(height: 40),
                    ],
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
  // SUB-WIDGET BUILDERS
  // ===========================================================================

  Widget _buildHeader(String userName) {
    final unreadAlerts = _alertService.unreadWarningCount;

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

        // Notifications / Alerts icon with badge
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: AppColors.darkText),
              onPressed: () {
                if (widget.onNavigateToTab != null) {
                  widget.onNavigateToTab!(3); // Alerts Tab
                }
              },
            ),
            if (unreadAlerts > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // ONBOARDING: ADD APPLIANCE HERO (WHEN NO APPLIANCES REGISTERED)
  // ===========================================================================

  Widget _buildOnboardingAddApplianceHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF246BFD).withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF246BFD).withValues(alpha: 0.5)),
            ),
            child: const Text(
              'SMART IOT MONITORING',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF93C5FD),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Register Your Appliance',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Connect your physical appliance to monitor real-time temperature, vibration, and sound telemetry.',
            style: TextStyle(fontSize: 13, color: Colors.grey[300], height: 1.4),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: widget.onNavigateToAddAppliance,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: const Text(
                'Register New Appliance',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPresetsSection() {
    final presets = [
      {'name': 'LG Inverter Refrigerator', 'type': 'Refrigerator', 'brand': 'LG', 'icon': Icons.kitchen_rounded},
      {'name': 'Samsung Front-Load Washer', 'type': 'Washing Machine', 'brand': 'Samsung', 'icon': Icons.local_laundry_service_rounded},
      {'name': 'Daikin Split Air Conditioner', 'type': 'Air Conditioner', 'brand': 'Daikin', 'icon': Icons.ac_unit_rounded},
      {'name': 'Panasonic Inverter Microwave', 'type': 'Microwave', 'brand': 'Panasonic', 'icon': Icons.microwave_rounded},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Quick Start Presets', style: AppTextStyles.heading3),
            if (_isRegisteringPreset)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Tap any preset to instantly register and begin telemetry:',
          style: AppTextStyles.caption.copyWith(fontSize: 12),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
          ),
          itemCount: presets.length,
          itemBuilder: (context, index) {
            final p = presets[index];
            return InkWell(
              onTap: _isRegisteringPreset
                  ? null
                  : () => _handleQuickPreset(p['name'] as String, p['type'] as String, p['brand'] as String),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowColor,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlueLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(p['icon'] as IconData, color: AppColors.primaryBlue, size: 18),
                        ),
                        const Icon(Icons.add_rounded, size: 18, color: AppColors.primaryBlue),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p['name'] as String,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${p['brand']} • ${p['type']}',
                          style: const TextStyle(fontSize: 10, color: AppColors.secondaryText),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSensorFeaturesExplanation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Monitored Parameters', style: AppTextStyles.heading3),
        const SizedBox(height: 10),
        _buildFeatureItem(
          icon: Icons.thermostat_rounded,
          color: const Color(0xFF0284C7),
          title: 'Temperature Telemetry',
          description: 'Tracks continuous thermal conditions and overheating in °C.',
        ),
        const SizedBox(height: 8),
        _buildFeatureItem(
          icon: Icons.vibration_rounded,
          color: const Color(0xFF7C3AED),
          title: 'Vibration Analysis',
          description: 'Detects mechanical rotor movement, balance, and oscillation in G.',
        ),
        const SizedBox(height: 8),
        _buildFeatureItem(
          icon: Icons.graphic_eq_rounded,
          color: const Color(0xFF0D9488),
          title: 'Acoustic Sound Level',
          description: 'Monitors operating noise levels and acoustic resonance in dB.',
        ),
      ],
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                Text(
                  description,
                  style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // FLEET MONITORING (WHEN APPLIANCES EXIST)
  // ===========================================================================

  Widget _buildFleetOverviewCard(int totalAppliances) {
    final alertCount = _alertService.allAlerts.length;

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
              const Text(
                'Operating Condition',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondaryText),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Operating Normally',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildFleetStat('$totalAppliances', 'Machines Active', AppColors.primaryBlue),
              Container(width: 1, height: 30, color: AppColors.borderColor),
              _buildFleetStat('$alertCount', 'Active Alerts', alertCount > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
              Container(width: 1, height: 30, color: AppColors.borderColor),
              _buildFleetStat('Active', 'Telemetry Stream', const Color(0xFF10B981)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFleetStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.secondaryText)),
      ],
    );
  }

  Widget _buildPowerControlCard() {
    final relayOn = _hardwareService.relayState;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: relayOn
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.power_settings_new_rounded,
                  color: relayOn ? const Color(0xFF10B981) : Colors.grey[600],
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appliance Power Control',
                    style: AppTextStyles.heading3.copyWith(fontSize: 13),
                  ),
                  Text(
                    relayOn ? 'Power active • Machine energized' : 'Standby • Power off',
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 5),
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
            // Clicking machine redirects directly to the Sensor Status Page alone!
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
}
