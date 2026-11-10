import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/appliance_service.dart';
import '../../services/analysis_service.dart';
import '../../services/gemini_chat_service.dart';
import '../../services/theme_service.dart';
import '../../services/hardware_serial_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_text_styles.dart';

/// Settings screen providing account management, theme customization,
/// hardware device diagnostics, and cloud synchronization controls.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _themeService = ThemeService();
  final _hardwareService = HardwareSerialService();

  bool _notificationsEnabled = true;

  Future<void> _showLogoutDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
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
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      await AuthService().logout();
      ApplianceService().clear();
      AnalysisService().clear();
      GeminiChatService().clearChat();

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Choose Theme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.brightness_auto_rounded),
                title: const Text('System Default'),
                trailing: _themeService.themeMode == ThemeMode.system
                    ? const Icon(Icons.check_rounded, color: AppColors.primaryBlue)
                    : null,
                onTap: () {
                  _themeService.setThemeMode(ThemeMode.system);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.light_mode_rounded),
                title: const Text('Light Mode'),
                trailing: _themeService.themeMode == ThemeMode.light
                    ? const Icon(Icons.check_rounded, color: AppColors.primaryBlue)
                    : null,
                onTap: () {
                  _themeService.setThemeMode(ThemeMode.light);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode_rounded),
                title: const Text('Dark Mode'),
                trailing: _themeService.themeMode == ThemeMode.dark
                    ? const Icon(Icons.check_rounded, color: AppColors.primaryBlue)
                    : null,
                onTap: () {
                  _themeService.setThemeMode(ThemeMode.dark);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return ListenableBuilder(
      listenable: Listenable.merge([authService, _themeService, _hardwareService]),
      builder: (context, _) {
        final user = authService.currentUser;
        final userName = user?.displayName ?? 'User';
        final userEmail = user?.email ?? 'user@example.com';
        final isHardwareLive = _hardwareService.isActive;

        String themeLabel = 'System';
        if (_themeService.themeMode == ThemeMode.dark) themeLabel = 'Dark Mode';
        if (_themeService.themeMode == ThemeMode.light) themeLabel = 'Light Mode';

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Settings & Configuration'),
            automaticallyImplyLeading: false,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Profile Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
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
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryBlueLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: AppColors.primaryBlue,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: AppTextStyles.heading3.copyWith(fontSize: 17),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                userEmail,
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: AppColors.primaryBlue,
                            size: 22,
                          ),
                          onPressed: () {
                            Navigator.pushNamed(context, '/edit-profile');
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Account Section
                  _buildSectionHeader('ACCOUNT'),
                  _buildSettingCard([
                    _buildSettingTile(
                      icon: Icons.person_outline_rounded,
                      title: 'Edit Profile',
                      onTap: () => Navigator.pushNamed(context, '/edit-profile'),
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // Hardware & IoT Diagnostics Section
                  _buildSectionHeader('MONITORING HARDWARE & CLOUD'),
                  _buildSettingCard([
                    _buildSettingTile(
                      icon: Icons.sensors_rounded,
                      title: 'Device Connection Status',
                      trailingText: isHardwareLive ? 'Online (COM3)' : 'Standby',
                      trailingColor: isHardwareLive ? const Color(0xFF10B981) : Colors.grey,
                      onTap: () {
                        if (!isHardwareLive) {
                          _hardwareService.connect('COM3');
                        }
                      },
                    ),
                    const Divider(height: 1, color: AppColors.dividerColor),
                    _buildSwitchTile(
                      icon: Icons.cloud_sync_rounded,
                      title: 'Auto-Sync to Supabase Cloud',
                      value: _hardwareService.autoSyncToCloud,
                      onChanged: (val) {
                        _hardwareService.setAutoSyncToCloud(val);
                      },
                    ),
                    const Divider(height: 1, color: AppColors.dividerColor),
                    _buildSettingTile(
                      icon: Icons.speed_rounded,
                      title: 'Total Telemetry Packets',
                      trailingText: '${_hardwareService.totalPacketsReceived} received',
                      onTap: () {},
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // Appearance & Application Section
                  _buildSectionHeader('APPEARANCE & APPLICATION'),
                  _buildSettingCard([
                    _buildSettingTile(
                      icon: Icons.palette_outlined,
                      title: 'App Theme',
                      trailingText: themeLabel,
                      onTap: _showThemeDialog,
                    ),
                    const Divider(height: 1, color: AppColors.dividerColor),
                    _buildSwitchTile(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifications & Alerts',
                      value: _notificationsEnabled,
                      onChanged: (val) {
                        setState(() {
                          _notificationsEnabled = val;
                        });
                      },
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // AI Assistant Section
                  _buildSectionHeader('AI & DIAGNOSTICS'),
                  _buildSettingCard([
                    _buildSettingTile(
                      icon: Icons.auto_awesome_rounded,
                      title: 'Appliance AI Assistant (Gemini 3.8)',
                      onTap: () => Navigator.pushNamed(context, '/chatbot'),
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // Support Section
                  _buildSectionHeader('SUPPORT'),
                  _buildSettingCard([
                    _buildSettingTile(
                      icon: Icons.help_outline_rounded,
                      title: 'Help & Support',
                      onTap: () {
                        showAboutDialog(
                          context: context,
                          applicationName: 'MyAppliance Monitor',
                          applicationVersion: '2.0.0',
                          applicationLegalese: 'Smart Appliance Monitoring & Predictive Failure System',
                        );
                      },
                    ),
                    const Divider(height: 1, color: AppColors.dividerColor),
                    _buildSettingTile(
                      icon: Icons.info_outline_rounded,
                      title: 'About Smart Appliance Monitor',
                      onTap: () {
                        showAboutDialog(
                          context: context,
                          applicationName: 'MyAppliance Monitor',
                          applicationVersion: '2.0.0',
                          applicationLegalese: '© 2026 Smart Appliance Systems Inc.',
                        );
                      },
                    ),
                  ]),
                  const SizedBox(height: 32),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _showLogoutDialog,
                      icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                      label: const Text(
                        'Logout',
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: AppTextStyles.label.copyWith(
          color: AppColors.secondaryText,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSettingCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? trailingText,
    Color? trailingColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.darkText, size: 22),
      title: Text(title, style: AppTextStyles.bodyMedium),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null) ...[
            Text(
              trailingText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: trailingColor ?? AppColors.secondaryText,
              ),
            ),
            const SizedBox(width: 6),
          ],
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.secondaryText,
          ),
        ],
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.darkText, size: 22),
      title: Text(title, style: AppTextStyles.bodyMedium),
      trailing: Switch(
        value: value,
        activeTrackColor: AppColors.primaryBlue,
        onChanged: onChanged,
      ),
    );
  }
}
