import 'package:flutter/material.dart';
import '../../models/appliance_model.dart';
import '../../services/auth_service.dart';
import '../../services/appliance_service.dart';
import '../../services/analysis_service.dart';
import '../../services/sensor_service.dart';
import '../../services/hardware_serial_service.dart';
import '../../services/hardware_mapping_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_text_styles.dart';
import '../../widgets/appliance_card.dart';
import '../../widgets/empty_state.dart';
import '../chat/chatbot_screen.dart';

/// Home Dashboard screen displaying greeting, hardware monitor engine status (COM3),
/// live sensor telemetry overview, and multi-appliance fleet management.
class HomeScreen extends StatefulWidget {
  final VoidCallback onNavigateToAddAppliance;

  const HomeScreen({
    super.key,
    required this.onNavigateToAddAppliance,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _hardwareService = HardwareSerialService();
  final _mappingService = HardwareMappingService();

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    ApplianceService().fetchAppliances();
    SensorService().fetchAllSensorReadings();
    _mappingService.init();

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
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  Future<void> _confirmRemoveAppliance(
    BuildContext context,
    ApplianceModel appliance,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Remove Appliance'),
          content: Text('Are you sure you want to remove "${appliance.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.secondaryText),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                minimumSize: const Size(100, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirm == true && context.mounted) {
      await ApplianceService().removeAppliance(appliance.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${appliance.name} removed.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openChatbot(BuildContext context) {
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
            child: const ChatbotScreen(),
          ),
        ),
      ),
    );
  }

  // Hardware Status Top Bar Widget
  Widget _buildHardwareStatusBar(ApplianceService applianceService) {
    final status = _hardwareService.status;
    final activePort = _hardwareService.activePort;
    final isLive = _hardwareService.isActive;

    // Find the single appliance designated to this COM port
    final assignedApplianceId = _mappingService.getApplianceIdForPort(activePort);
    final assignedAppliance = assignedApplianceId != null
        ? applianceService.getApplianceById(assignedApplianceId)
        : null;

    Color badgeColor;
    String statusTitle;
    IconData badgeIcon;

    switch (status) {
      case HardwareConnectionStatus.connected:
        badgeColor = const Color(0xFF10B981);
        statusTitle = 'Hardware Online: $activePort';
        badgeIcon = Icons.check_circle_rounded;
        break;
      case HardwareConnectionStatus.simulated:
        badgeColor = const Color(0xFF8B5CF6);
        statusTitle = 'Simulated Hardware: $activePort';
        badgeIcon = Icons.stream_rounded;
        break;
      case HardwareConnectionStatus.connecting:
        badgeColor = const Color(0xFFF59E0B);
        statusTitle = 'Connecting $activePort...';
        badgeIcon = Icons.sync_rounded;
        break;
      case HardwareConnectionStatus.error:
      case HardwareConnectionStatus.disconnected:
        badgeColor = Colors.blueGrey;
        statusTitle = 'Hardware Unit: $activePort';
        badgeIcon = Icons.sensors_off_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        children: [
          Icon(badgeIcon, color: badgeColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
                Text(
                  assignedAppliance != null
                      ? 'Exclusively monitoring: ${assignedAppliance.name}'
                      : 'Unassigned • Open appliance details to link',
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isLive) ...[
            // Quick relay toggle button
            InkWell(
              onTap: () {
                _hardwareService.toggleRelay();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _hardwareService.relayState
                          ? 'Relay switched OFF'
                          : 'Relay switched ON',
                    ),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _hardwareService.relayState
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.power_settings_new_rounded,
                      size: 14,
                      color: _hardwareService.relayState
                          ? Colors.green[800]
                          : Colors.grey[700],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _hardwareService.relayState ? 'ON' : 'OFF',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _hardwareService.relayState
                            ? Colors.green[800]
                            : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            TextButton(
              onPressed: () => _hardwareService.connect(activePort),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text('Connect', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTelemetryOverviewCard(SensorService sensorService) {
    final metrics = sensorService.overallFleetMetrics;
    final hasReadings = metrics.readingCount > 0;
    final isSyncing = sensorService.isFetchingAll;

    Color statusColor;
    switch (metrics.healthStatus) {
      case 'Good':
        statusColor = AppColors.success;
        break;
      case 'Average':
        statusColor = AppColors.warning;
        break;
      case 'Poor':
        statusColor = AppColors.error;
        break;
      default:
        statusColor = AppColors.secondaryText;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Title & Sync status + Sync button
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlueLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.sensors_rounded,
                  color: AppColors.primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Telemetry Analytics (Supabase)',
                          style: AppTextStyles.heading3.copyWith(fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isSyncing
                                ? AppColors.warning
                                : (hasReadings ? AppColors.success : AppColors.secondaryText),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      hasReadings
                          ? '${metrics.readingCount} readings recorded • Health: ${metrics.healthStatus}'
                          : (isSyncing
                              ? 'Syncing sensor readings...'
                              : 'Supabase connected • Ready for telemetry'),
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        color: hasReadings ? statusColor : AppColors.secondaryText,
                        fontWeight: hasReadings ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSyncing)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryBlue,
                  ),
                )
              else
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(
                    Icons.sync_rounded,
                    size: 20,
                    color: AppColors.secondaryText,
                  ),
                  tooltip: 'Sync Supabase telemetry',
                  onPressed: () => sensorService.fetchAllSensorReadings(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.dividerColor),
          const SizedBox(height: 12),

          // 3 Metric Columns: Temperature, Vibration, Sound
          Row(
            children: [
              Expanded(
                child: _buildTelemetryMetric(
                  icon: Icons.thermostat_rounded,
                  label: 'Temperature',
                  value: hasReadings ? '${metrics.averageTemperature}°C' : '--',
                  accentColor: const Color(0xFFF97316),
                ),
              ),
              Container(
                height: 34,
                width: 1,
                color: AppColors.borderColor,
              ),
              Expanded(
                child: _buildTelemetryMetric(
                  icon: Icons.vibration_rounded,
                  label: 'Vibration',
                  value: hasReadings ? '${metrics.averageVibration}' : '--',
                  accentColor: const Color(0xFF8B5CF6),
                ),
              ),
              Container(
                height: 34,
                width: 1,
                color: AppColors.borderColor,
              ),
              Expanded(
                child: _buildTelemetryMetric(
                  icon: Icons.graphic_eq_rounded,
                  label: 'Sound',
                  value: hasReadings ? '${metrics.averageSound.round()} dB' : '--',
                  accentColor: const Color(0xFF0EA5E9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color accentColor,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: accentColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.heading2.copyWith(
            fontSize: 15,
            color: AppColors.darkText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final applianceService = ApplianceService();
    final analysisService = AnalysisService();
    final sensorService = SensorService();

    final user = authService.currentUser;
    final userName = user?.displayName ?? 'User';

    return ListenableBuilder(
      listenable: Listenable.merge([
        applianceService,
        analysisService,
        sensorService,
        _hardwareService,
        _mappingService,
      ]),
      builder: (context, _) {
        final allAppliances = applianceService.appliances;
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
                      applianceService.fetchAppliances(),
                      sensorService.fetchAllSensorReadings(),
                    ]);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        // Header Row: Avatar + Greeting + AI Icon + Notifications
                        Row(
                          children: [
                            // Avatar
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlueLight,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                color: AppColors.primaryBlue,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Greeting & Name
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getGreeting(),
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                  Text(
                                    'Hello, $userName',
                                    style: AppTextStyles.heading2.copyWith(fontSize: 20),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // AI Assistant Shortcut Icon
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlueLight,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primaryBlue.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: IconButton(
                                tooltip: 'Appliance AI Assistant',
                                icon: const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: AppColors.primaryBlue,
                                  size: 20,
                                ),
                                onPressed: () => _openChatbot(context),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Notification Icon
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.borderColor, width: 1),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.notifications_none_rounded,
                                  color: AppColors.darkText,
                                  size: 22,
                                ),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('All appliance telemetry systems operational.'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Real-time Hardware Monitor Status Bar (COM3)
                        _buildHardwareStatusBar(applianceService),
                        const SizedBox(height: 14),

                        // Search Bar
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderColor, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.shadowColor,
                                blurRadius: 12,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: AppTextStyles.bodyMedium,
                            decoration: const InputDecoration(
                              hintText: 'Search appliance...',
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: AppColors.secondaryText,
                                size: 22,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Live Sensor Telemetry Overview from Supabase
                        _buildTelemetryOverviewCard(sensorService),
                        const SizedBox(height: 16),

                        // Section Header: My Appliances + Add Appliance Action
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'My Appliances',
                              style: AppTextStyles.heading3,
                            ),
                            TextButton.icon(
                              onPressed: widget.onNavigateToAddAppliance,
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                                size: 18,
                                color: AppColors.primaryBlue,
                              ),
                              label: Text(
                                'Add Appliance',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.primaryBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Appliances Content Area
                        Expanded(
                          child: applianceService.isLoading && allAppliances.isEmpty
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primaryBlue,
                                  ),
                                )
                              : allAppliances.isEmpty
                                  ? ListView(
                                      children: [
                                        const SizedBox(height: 30),
                                        EmptyStateWidget(
                                          icon: Icons.kitchen_outlined,
                                          title: 'No appliances added yet',
                                          subtitle:
                                              'Add your appliances to start monitoring with COM3 sensors.',
                                          buttonText: 'Add Appliance',
                                          onButtonPressed: widget.onNavigateToAddAppliance,
                                        ),
                                      ],
                                    )
                                  : filteredAppliances.isEmpty
                                      ? ListView(
                                          children: const [
                                            SizedBox(height: 30),
                                            EmptyStateWidget(
                                              icon: Icons.search_off_rounded,
                                              title: 'No appliances found',
                                              subtitle: 'Try searching with a different keyword.',
                                            ),
                                          ],
                                        )
                                      : ListView.builder(
                                          physics: const AlwaysScrollableScrollPhysics(
                                            parent: BouncingScrollPhysics(),
                                          ),
                                          padding: const EdgeInsets.only(bottom: 80),
                                          itemCount: filteredAppliances.length,
                                          itemBuilder: (context, index) {
                                            final appliance = filteredAppliances[index];
                                            final latestAnalysis =
                                                analysisService.getLatestAnalysisForAppliance(appliance.id);
                                            final healthMetrics =
                                                sensorService.getHealthMetricsForAppliance(appliance.id, appliance.name);
                                            final latestReading =
                                                sensorService.getLatestReadingForAppliance(appliance.id, appliance.name);

                                            return ApplianceCard(
                                              appliance: appliance,
                                              latestAnalysis: latestAnalysis,
                                              healthMetrics: healthMetrics,
                                              latestReading: latestReading,
                                              onTap: () {
                                                Navigator.pushNamed(
                                                  context,
                                                  '/appliance-details',
                                                  arguments: appliance,
                                                );
                                              },
                                              onLongPress: () {
                                                _confirmRemoveAppliance(context, appliance);
                                              },
                                            );
                                          },
                                        ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Floating AI Assistant Button in this screen
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
                      onPressed: () => _openChatbot(context),
                      icon: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: const Text(
                        'AI Diagnostic',
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
}
