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
import '../chat/chatbot_screen.dart';

/// Commercial-grade Home Dashboard for Smart Appliance Monitoring.
/// Award-winning design providing seamless onboarding when no machines exist,
/// and instant redirection to individual sensor readings upon appliance selection.
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
            content: Text('${appliance.name} registered! Tap it to view live sensor readings.'),
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
        final hasAppliances = allAppliances.isNotEmpty;

        // Active Appliance to display
        ApplianceModel? primaryAppliance;
        if (hasAppliances) {
          primaryAppliance = allAppliances.firstWhere(
            (a) => a.id == _selectedApplianceId,
            orElse: () => allAppliances.first,
          );
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

                        // 1. HEADER ROW: Clean branding, greeting, alerts bell (No "Online" button)
                        _buildHeader(userName),
                        const SizedBox(height: 18),

                        // IF NO APPLIANCES ARE REGISTERED: Show Add Appliance Onboarding Hub
                        if (!hasAppliances) ...[
                          _buildOnboardingAddApplianceHero(),
                          const SizedBox(height: 24),
                          _buildQuickPresetsSection(),
                          const SizedBox(height: 24),
                          _buildSensorFeaturesExplanation(),
                          const SizedBox(height: 80),
                        ] else ...[
                          // IF APPLIANCES EXIST: Show Fleet Dashboard & Machine Click Redirection
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
                          _buildAppliancesList(filteredAppliances, analysisService),
                          const SizedBox(height: 80),
                        ],
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

  Widget _buildHeader(String userName) {
    final unreadAlerts = _alertService.unreadWarningCount;

    return Row(
      children: [
        // App Icon Avatar
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.primaryBlueLight,
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.shield_outlined,
            color: AppColors.primaryBlue,
            size: 26,
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF246BFD).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF246BFD).withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.sensors_rounded, size: 12, color: Color(0xFF60A5FA)),
                    SizedBox(width: 4),
                    Text(
                      'IOT TELEMETRY READY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF93C5FD),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Register Your First Appliance',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your home appliance to start capturing live temperature, vibration, and sound telemetry from your ESP32 device.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[300],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: widget.onNavigateToAddAppliance,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
              label: const Text(
                'Register New Appliance',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
        const SizedBox(height: 6),
        Text(
          'Tap any preset to instantly register and begin monitoring:',
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
            childAspectRatio: 1.45,
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
                      blurRadius: 10,
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
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlueLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(p['icon'] as IconData, color: AppColors.primaryBlue, size: 20),
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
        Text('Monitored Sensor Parameters', style: AppTextStyles.heading3),
        const SizedBox(height: 12),
        _buildFeatureItem(
          icon: Icons.thermostat_rounded,
          color: const Color(0xFF0284C7),
          title: 'Temperature Telemetry',
          description: 'Tracks DS18B20 & MPU6050 thermal drift and compressor overheating in real time.',
        ),
        const SizedBox(height: 10),
        _buildFeatureItem(
          icon: Icons.vibration_rounded,
          color: const Color(0xFF7C3AED),
          title: '3-Axis Vibration Analysis',
          description: 'Detects bearing chatter, motor imbalance, and mechanical rotor oscillation in G-force.',
        ),
        const SizedBox(height: 10),
        _buildFeatureItem(
          icon: Icons.graphic_eq_rounded,
          color: const Color(0xFF0D9488),
          title: 'Acoustic Sound Monitoring',
          description: 'Analyzes high-frequency harmonic spikes and noise levels in decibels via INMP441.',
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(fontSize: 11, color: AppColors.secondaryText, height: 1.3),
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
                'Fleet Monitoring Status',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondaryText),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'All Systems Operational',
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
              Container(width: 1, height: 32, color: AppColors.borderColor),
              _buildFleetStat('$alertCount', 'Active Alerts', alertCount > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
              Container(width: 1, height: 32, color: AppColors.borderColor),
              _buildFleetStat('COM3', 'Telemetry Link', const Color(0xFF7C3AED)),
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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
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
                    relayOn ? 'Power active • Relay Pin 27 energized' : 'Standby • Power disconnected',
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
