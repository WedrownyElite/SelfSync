// ignore_for_file: unused_field
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/theme_service.dart';
import '../services/analytics_service.dart';
import '../services/mood_service.dart';
import '../services/onboarding_service.dart';
import '../services/auth_service.dart';
import '../services/cloud_backup_service.dart';
import '../widgets/side_drawer.dart';
import '../utils/app_logger.dart';
import '../constants/app_constants.dart';
import 'bug_report_screen.dart';


class SettingsScreen extends StatefulWidget {
  final ThemeService themeService;
  final AnalyticsService analyticsService;
  final SideDrawerController drawerController;
  final OnboardingService onboardingService;
  final MoodService moodService;
  final AuthService authService;
  final CloudBackupService cloudBackupService;

  // Tutorial keys
  final GlobalKey? themeModesKey;
  final GlobalKey? colorThemesKey;
  final GlobalKey? privacyKey;
  final GlobalKey? aboutKey;

  const SettingsScreen({
    super.key,
    required this.themeService,
    required this.analyticsService,
    required this.drawerController,
    required this.onboardingService,
    required this.moodService,
    required this.authService,
    required this.cloudBackupService,
    this.themeModesKey,
    this.colorThemesKey,
    this.privacyKey,
    this.aboutKey,
  });

  @override
  State<SettingsScreen> createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  final ScrollController _scrollController = ScrollController();

  // Onboarding control
  bool _isOnboardingActive = false;
  int _onboardingStep = 0;

  @override
  void initState() {
    super.initState();
    widget.themeService.addListener(_onThemeChanged);
    widget.analyticsService.addListener(_onAnalyticsChanged);
    widget.cloudBackupService.addListener(_onCloudBackupChanged);
  }

  @override
  void dispose() {
    widget.themeService.removeListener(_onThemeChanged);
    widget.analyticsService.removeListener(_onAnalyticsChanged);
    widget.cloudBackupService.removeListener(_onCloudBackupChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _openBugReportScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BugReportScreen(
          analyticsService: widget.analyticsService,
        ),
      ),
    );
  }

  void _onThemeChanged() {
    setState(() {});
  }

  void _onAnalyticsChanged() {
    setState(() {});
  }

  void _onCloudBackupChanged() {
    setState(() {});
  }

  void startOnboarding() {
    setState(() {
      _isOnboardingActive = true;
      _onboardingStep = 0;
    });
    AppLogger.info('Settings onboarding started', tag: 'SettingsScreen');
  }

  void setOnboardingStep(int step) {
    setState(() {
      _onboardingStep = step;
    });
    AppLogger.info('Settings onboarding step set to: $step', tag: 'SettingsScreen');
  }

  void endOnboarding() {
    setState(() {
      _isOnboardingActive = false;
      _onboardingStep = 0;
    });
    AppLogger.info('Settings onboarding ended', tag: 'SettingsScreen');
  }

  void scrollToWidget(GlobalKey? key) {
    if (key == null) {
      AppLogger.warning('Cannot scroll - key is null', tag: 'SettingsScreen');
      return;
    }

    final screenHeight = MediaQuery.of(context).size.height;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;

        final renderObject = key.currentContext?.findRenderObject();
        if (renderObject == null || renderObject is! RenderBox) {
          AppLogger.warning('Cannot scroll - render object is null or not a RenderBox', tag: 'SettingsScreen');
          return;
        }

        try {
          final widgetPosition = renderObject.localToGlobal(Offset.zero);
          final widgetHeight = renderObject.size.height;
          final currentScroll = _scrollController.offset;

          const headerHeight = 80.0;
          final viewportTop = headerHeight;
          final viewportBottom = screenHeight - 100;
          final viewportHeight = viewportBottom - viewportTop;

          final widgetTopInViewport = widgetPosition.dy;

          AppLogger.info('Widget position - Top: $widgetTopInViewport', tag: 'SettingsScreen.Scroll');

          final targetScrollOffset = currentScroll + widgetTopInViewport - viewportTop - (viewportHeight / 2) + (widgetHeight / 2);

          final maxScroll = _scrollController.position.maxScrollExtent;
          final minScroll = _scrollController.position.minScrollExtent;
          final finalScroll = targetScrollOffset.clamp(minScroll, maxScroll);

          AppLogger.info('Scrolling from $currentScroll to $finalScroll (max: $maxScroll)', tag: 'SettingsScreen.Scroll');

          _scrollController.animateTo(
            finalScroll,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutCubic,
          );

          AppLogger.success('Scroll animation started', tag: 'SettingsScreen.Scroll');
        } catch (e, stackTrace) {
          AppLogger.error('Failed to scroll to widget: $e\n$stackTrace', tag: 'SettingsScreen.Scroll');
        }
      });
    });
  }

  void scrollToTop() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      if (!_scrollController.hasClients) {
        AppLogger.warning('ScrollController not attached yet', tag: 'SettingsScreen.Scroll');
        return;
      }

      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: _isOnboardingActive
                    ? const NeverScrollableScrollPhysics()
                    : null,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _buildAccountSection(theme),
                    const SizedBox(height: 16), 
                    _buildThemeModeSection(theme),
                    const SizedBox(height: 16),
                    _buildColorGradientSection(theme),
                    const SizedBox(height: 16),
                    _buildPrivacySection(theme),
                    const SizedBox(height: 16),
                    _buildOnboardingSection(theme),
                    const SizedBox(height: 16),
                    _buildDataManagementSection(theme),
                    const SizedBox(height: 24),
                    _buildAboutSection(theme),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Back',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Customize your experience',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection(ThemeData theme) {
    final user = widget.authService.currentUser;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_circle_rounded,
                size: 24,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(
                'Account',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // User info
          if (user != null) ...[
            Row(
              children: [
                if (user.photoURL != null)
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: NetworkImage(user.photoURL!),
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  )
                else
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.person_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (user.displayName != null)
                        Text(
                          user.displayName!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      Text(
                        user.email ?? 'No email',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Auto backup toggle
            _buildPrivacyToggle(
              theme: theme,
              title: 'Automatic Cloud Backups',
              description: 'Automatically backup your mood data to the cloud',
              value: widget.cloudBackupService.autoBackupEnabled,
              onChanged: (value) async {
                await widget.cloudBackupService.setAutoBackupEnabled(value);

                if (value && mounted) {
                  // Perform immediate backup when enabled
                  final entries = widget.moodService.getAllEntries();
                  await widget.cloudBackupService.backupToCloud(entries);

                  if (mounted) {  // ADD THIS CHECK
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Auto backup enabled and data backed up'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 20),
          ],

          // Sign out button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  await widget.authService.signOut();
                }
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeModeSection(ThemeData theme) {
    return Container(
      key: widget.themeModesKey,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.brightness_6_rounded,
                size: 24,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme Mode',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Choose your display preference',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildThemeModeOption(
                  theme: theme,
                  mode: ThemeMode.light,
                  icon: Icons.light_mode_rounded,
                  label: 'Light',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildThemeModeOption(
                  theme: theme,
                  mode: ThemeMode.dark,
                  icon: Icons.dark_mode_rounded,
                  label: 'Dark',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildThemeModeOption(
                  theme: theme,
                  mode: ThemeMode.system,
                  icon: Icons.auto_mode_rounded,
                  label: 'Auto',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeModeOption({
    required ThemeData theme,
    required ThemeMode mode,
    required IconData icon,
    required String label,
  }) {
    final isSelected = widget.themeService.themeMode == mode;

    return InkWell(
      onTap: () async {
        await widget.themeService.setThemeMode(mode);
        widget.analyticsService.trackThemeChange(
          mode.toString(),
          widget.themeService.selectedGradient.toString(),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorGradientSection(ThemeData theme) {
    return Container(
      key: widget.colorThemesKey,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.palette_rounded,
                size: 24,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Color Theme',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Changes your mood rating colors',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: ColorGradientOption.values.map((gradient) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildColorOption(theme: theme, gradient: gradient),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildColorOption({
    required ThemeData theme,
    required ColorGradientOption gradient,
  }) {
    final isSelected = widget.themeService.selectedGradient == gradient;

    // Get theme name
    String themeName;
    switch (gradient) {
      case ColorGradientOption.purpleBlue:
        themeName = 'Purple Dream';
        break;
      case ColorGradientOption.sunsetOrange:
        themeName = 'Sunset Glow';
        break;
      case ColorGradientOption.oceanTeal:
        themeName = 'Ocean Breeze';
        break;
      case ColorGradientOption.forestGreen:
        themeName = 'Forest Calm';
        break;
      case ColorGradientOption.rosePink:
        themeName = 'Rose Garden';
        break;
      case ColorGradientOption.goldenAmber:
        themeName = 'Golden Hour';
        break;
      case ColorGradientOption.arcticBlue:
        themeName = 'Arctic Frost';
        break;
      case ColorGradientOption.lavenderMist:
        themeName = 'Lavender Mist';
        break;
    }

    return InkWell(
      onTap: () async {
        await widget.themeService.setColorGradient(gradient);
        widget.analyticsService.trackThemeChange(
          widget.themeService.themeMode.toString(),
          gradient.toString(),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Gradient preview bar
            Container(
              width: 60,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradient.colors.gradientColors,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: gradient.colors.primary.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Theme name
            Expanded(
              child: Text(
                themeName,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
            // Checkmark for selected
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacySection(ThemeData theme) {
    return Container(
      key: widget.privacyKey,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.privacy_tip_rounded,
                size: 24,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Privacy & Analytics',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Control your data sharing',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildPrivacyToggle(
            theme: theme,
            title: 'Usage Analytics',
            description: 'Help improve the app with anonymous usage data',
            value: widget.analyticsService.analyticsEnabled,
            onChanged: (value) {
              widget.analyticsService.setAnalyticsEnabled(value);
            },
          ),
          const SizedBox(height: 16),
          _buildPrivacyToggle(
            theme: theme,
            title: 'Crash Reports',
            description: 'Automatically send error reports to fix issues',
            value: widget.analyticsService.crashReportingEnabled,
            onChanged: (value) {
              widget.analyticsService.setCrashReportingEnabled(value);
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'All mood data stays on your device. These settings only affect anonymous usage statistics.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyToggle({
    required ThemeData theme,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: theme.colorScheme.primary,
          activeThumbColor: theme.colorScheme.onPrimary,
        ),
      ],
    );
  }

  Widget _buildOnboardingSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.school_rounded,
                size: 24,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Help & Tutorial',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Take the guided tour again',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                // Reset both privacy policy and tutorial
                await widget.onboardingService.resetPrivacyPolicy();
                await widget.onboardingService.resetTutorial();

                if (mounted) {
                  Navigator.of(context).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Tutorial and privacy policy reset. Restart the app to see the welcome screen.'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Restart Tutorial'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataManagementSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.storage_rounded,
                size: 24,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data Management',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Manage your stored data',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Restore from Backup - ADD THIS
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showRestoreBackupDialog(context, theme),
              icon: const Icon(Icons.cloud_download_rounded),
              label: const Text('Restore from Backup'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Clear Local Data
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showClearDataDialog(context, theme),
              icon: const Icon(Icons.delete_sweep_rounded),
              label: const Text('Clear Local Data'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(
                  color: theme.colorScheme.error.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Manage Cloud Backups
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showManageBackupsDialog(context, theme),
              icon: const Icon(Icons.cloud_off_rounded),
              label: const Text('Manage Cloud Backups'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(
                  color: theme.colorScheme.error.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Delete Account
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _showDeleteAccountDialog(context, theme),
              icon: const Icon(Icons.person_remove_rounded),
              label: const Text('Delete Account'),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(BuildContext context, ThemeData theme) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.warning_rounded,
          color: theme.colorScheme.error,
          size: 48,
        ),
        title: const Text('Clear Local Data?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently delete from this device:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildDeleteItem('All mood entries', theme),
            _buildDeleteItem('Mood history and trends', theme),
            _buildDeleteItem('Streak records', theme),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your cloud backups will NOT be affected. You can restore your data anytime.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await widget.moodService.clearAllData();
              widget.analyticsService.trackEvent('local_data_cleared');

              if (context.mounted) {
                Navigator.pop(dialogContext);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Local data cleared successfully'),
                    backgroundColor: theme.colorScheme.error,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: const Text('Clear Local Data'),
          ),
        ],
      ),
    );
  }

  void _showManageBackupsDialog(BuildContext context, ThemeData theme) async {
    // Capture the context before any async operations
    final scaffoldContext = context;

    // Show loading dialog
    showDialog(
      context: scaffoldContext,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading backups...',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );

    // Check if backups exist
    final hasBackup = await widget.cloudBackupService.hasCloudBackup();

    if (!mounted) return;

    // Use Navigator with the captured context
    if (scaffoldContext.mounted) {
      Navigator.pop(scaffoldContext); // Close loading dialog
    }

    if (!hasBackup) {
      if (scaffoldContext.mounted) {
        showDialog(
          context: scaffoldContext,
          builder: (context) => AlertDialog(
            icon: Icon(
              Icons.cloud_off_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              size: 48,
            ),
            title: const Text('No Backups Found'),
            content: const Text('You don\'t have any cloud backups yet. Enable automatic backups in the Account section to start backing up your data.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Get backup metadata
    final metadata = await widget.cloudBackupService.getLatestBackupMetadata();

    if (!mounted || metadata == null) return;

    if (scaffoldContext.mounted) {
      showDialog(
        context: scaffoldContext,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(
            Icons.cloud_rounded,
            color: theme.colorScheme.primary,
            size: 48,
          ),
          title: const Text('Manage Cloud Backups'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Latest Backup:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ${metadata.entryCount} mood entries'),
                    Text('• Created: ${_formatBackupDate(metadata.createdAt)}'),
                    Text('• Size: ${metadata.formattedSize}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 20,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Deleting backups is permanent and cannot be undone.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showDeleteBackupsConfirmation(scaffoldContext, theme);
              },
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              child: const Text('Delete All Backups'),
            ),
          ],
        ),
      );
    }
  }

  void _showDeleteBackupsConfirmation(BuildContext context, ThemeData theme) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.delete_forever_rounded,
          color: theme.colorScheme.error,
          size: 48,
        ),
        title: const Text('Delete All Cloud Backups?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will permanently delete all your cloud backups. You will NOT be able to:'),
            const SizedBox(height: 12),
            _buildDeleteItem('Restore your data on other devices', theme),
            _buildDeleteItem('Recover data if you lose this device', theme),
            _buildDeleteItem('Access any backed up mood entries', theme),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Your local data on this device will NOT be affected.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              // Show progress
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Deleting backups...'),
                      ],
                    ),
                  ),
                ),
              );

              final success = await widget.cloudBackupService.deleteAllCloudBackups();

              if (context.mounted) {
                Navigator.pop(context); // Close progress dialog

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'All cloud backups deleted successfully'
                        : 'Failed to delete backups'),
                    backgroundColor: success ? theme.colorScheme.error : null,
                    behavior: SnackBarBehavior.floating,
                  ),
                );

                if (success) {
                  widget.analyticsService.trackEvent('cloud_backups_deleted');
                  await widget.cloudBackupService.setAutoBackupEnabled(false);
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: const Text('Delete All Backups'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, ThemeData theme) {
    final TextEditingController confirmController = TextEditingController();
    bool isDisposed = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false, // Prevent back button
        child: AlertDialog(
          icon: Icon(
            Icons.warning_rounded,
            color: theme.colorScheme.error,
            size: 48,
          ),
          title: const Text('Delete Account?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This will permanently delete:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDeleteItem('Your account and profile', theme),
                _buildDeleteItem('All cloud backups', theme),
                _buildDeleteItem('All mood data from our servers', theme),
                _buildDeleteItem('Your app settings and preferences', theme),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.error,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: theme.colorScheme.error,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'THIS ACTION CANNOT BE UNDONE',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'All your data will be permanently lost',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Type DELETE to confirm:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmController,
                  decoration: InputDecoration(
                    hintText: 'Type DELETE',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.colorScheme.error),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
                    ),
                  ),
                  autocorrect: false,
                  enableSuggestions: false,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                // Dispose after dialog closes
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (!isDisposed) {
                    confirmController.dispose();
                    isDisposed = true;
                  }
                });
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (confirmController.text.trim().toUpperCase() != 'DELETE') {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Please type DELETE to confirm'),
                        backgroundColor: theme.colorScheme.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                  return;
                }

                // Close dialog FIRST
                Navigator.pop(dialogContext);

                // Dispose controller AFTER a delay to let animation finish
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (!isDisposed) {
                    confirmController.dispose();
                    isDisposed = true;
                  }
                });

                // Show confirmation after dialog is closed
                if (context.mounted) {
                  await Future.delayed(const Duration(milliseconds: 100));
                  if (context.mounted) {
                    _performAccountDeletion(context, theme);
                  }
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              child: const Text('Delete Account'),
            ),
          ],
        ),
      ),
    ).then((_) {
      // Safety net: dispose if still not disposed after dialog closes
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!isDisposed) {
          try {
            confirmController.dispose();
            isDisposed = true;
          } catch (_) {
            // Already disposed, ignore
          }
        }
      });
    });
  }

  Future<void> _performAccountDeletion(BuildContext context, ThemeData theme) async {
    final scaffoldContext = context;

    // Show progress
    showDialog(
      context: scaffoldContext,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Deleting account...',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Delete cloud backups first
    await widget.cloudBackupService.deleteAllCloudBackups();

    // Clear local data
    await widget.moodService.clearAllData();

    // Try to delete Firebase account
    bool accountDeleted = false;
    bool needsReauth = false;

    try {
      accountDeleted = await widget.authService.deleteAccount();
    } catch (e) {
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('requires-recent-login') ||
          errorString.contains('recent-login') ||
          errorString.contains('reauthenticate')) {
        needsReauth = true;
      }
    }

    if (scaffoldContext.mounted) {
      Navigator.pop(scaffoldContext); // Close progress dialog

      if (needsReauth) {
        // Show re-authentication dialog with direct sign-in
        _showReauthenticationDialog(scaffoldContext, theme);
      } else if (accountDeleted) {
        widget.analyticsService.trackEvent('account_deleted');

        // Close settings screen to show auth screen
        if (scaffoldContext.mounted) {
          Navigator.pop(scaffoldContext);
        }

        // Show success message
        if (scaffoldContext.mounted) {
          ScaffoldMessenger.of(scaffoldContext).showSnackBar(
            SnackBar(
              content: const Text('Account deleted successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Some other error occurredaw
        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
          SnackBar(
            content: const Text('Failed to delete account. Please try again or contact support.'),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showReauthenticationDialog(BuildContext context, ThemeData theme) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.lock_reset_rounded,
          color: theme.colorScheme.primary,
          size: 48,
        ),
        title: const Text('Re-authentication Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'For your security, deleting your account requires recent authentication.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'You\'ll be signed out so you can sign back in to confirm your identity.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // Close dialog

              try {
                // Create a fresh GoogleSignIn instance
                final googleSignIn = GoogleSignIn();

                // First disconnect to revoke access
                await googleSignIn.disconnect();

                // Then sign out to clear any remaining state
                await googleSignIn.signOut();
              } catch (e) {
                // Ignore errors - user might not be signed in with Google
              }

              // Sign out from Firebase
              await widget.authService.signOut();

              // Close settings screen
              if (context.mounted) {
                Navigator.pop(context);
              }

              // Show instruction message on auth screen
              if (context.mounted) {
                await Future.delayed(const Duration(milliseconds: 500));

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please sign in again, then go to Settings to delete your account.'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 5),
                    ),
                  );
                }
              }
            },
            child: const Text('Sign In Again'),
          ),
        ],
      ),
    );
  }

  void _showRestoreBackupDialog(BuildContext context, ThemeData theme) async {
    final scaffoldContext = context;

    // Show loading dialog
    showDialog(
      context: scaffoldContext,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading backups...',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );

    // Check if backups exist
    final hasBackup = await widget.cloudBackupService.hasCloudBackup();

    if (!mounted) return;

    if (scaffoldContext.mounted) {
      Navigator.pop(scaffoldContext); // Close loading dialog
    }

    if (!hasBackup) {
      if (scaffoldContext.mounted) {
        showDialog(
          context: scaffoldContext,
          builder: (context) => AlertDialog(
            icon: Icon(
              Icons.cloud_off_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              size: 48,
            ),
            title: const Text('No Backups Found'),
            content: const Text('You don\'t have any cloud backups to restore. Enable automatic backups in the Account section to start backing up your data.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Get backup metadata
    final metadata = await widget.cloudBackupService.getLatestBackupMetadata();

    if (!mounted || metadata == null) return;

    // Check if user has local data
    final localEntries = widget.moodService.getAllEntries();
    final hasLocalData = localEntries.isNotEmpty;

    if (scaffoldContext.mounted) {
      showDialog(
        context: scaffoldContext,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(
            Icons.cloud_download_rounded,
            color: theme.colorScheme.primary,
            size: 48,
          ),
          title: const Text('Restore from Backup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available Backup:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ${metadata.entryCount} mood entries'),
                    Text('• Created: ${_formatBackupDate(metadata.createdAt)}'),
                    Text('• Size: ${metadata.formattedSize}'),
                  ],
                ),
              ),
              if (hasLocalData) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You have ${localEntries.length} mood ${localEntries.length == 1 ? "entry" : "entries"} on this device.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'How would you like to restore?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            if (hasLocalData)
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _performRestore(scaffoldContext, theme, mergeData: true);
                },
                child: const Text('Merge with Local'),
              ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                if (hasLocalData) {
                  _showReplaceDataConfirmation(scaffoldContext, theme);
                } else {
                  _performRestore(scaffoldContext, theme, mergeData: false);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: hasLocalData ? theme.colorScheme.error : theme.colorScheme.primary,
                foregroundColor: hasLocalData ? theme.colorScheme.onError : theme.colorScheme.onPrimary,
              ),
              child: Text(hasLocalData ? 'Replace Local Data' : 'Restore'),
            ),
          ],
        ),
      );
    }
  }

  void _showReplaceDataConfirmation(BuildContext context, ThemeData theme) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.warning_rounded,
          color: theme.colorScheme.error,
          size: 48,
        ),
        title: const Text('Replace Local Data?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will permanently delete all your current local data and replace it with the backup.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 20,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your current local data will be lost. This cannot be undone.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _performRestore(context, theme, mergeData: false);
            },
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: const Text('Replace Data'),
          ),
        ],
      ),
    );
  }

  Future<void> _performRestore(BuildContext context, ThemeData theme, {required bool mergeData}) async {
    final scaffoldContext = context;

    // Show progress
    showDialog(
      context: scaffoldContext,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                mergeData ? 'Merging data...' : 'Restoring backup...',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final entries = await widget.cloudBackupService.restoreFromCloud();

      if (!mounted) return;

      if (entries != null && entries.isNotEmpty) {
        if (!mergeData) {
          // Replace mode: clear local data first
          await widget.moodService.clearAllData();
        }

        // Import all entries from backup
        int importedCount = 0;
        for (final entry in entries) {
          // Check for duplicates when merging
          if (mergeData) {
            final existingEntry = widget.moodService.getAllEntries()
                .where((e) => e.id == entry.id)
                .firstOrNull;

            if (existingEntry == null) {
              widget.moodService.importEntry(entry);
              importedCount++;
            }
          } else {
            widget.moodService.importEntry(entry);
            importedCount++;
          }
        }

        if (scaffoldContext.mounted) {
          Navigator.pop(scaffoldContext); // Close progress dialog

          final message = mergeData
              ? 'Successfully merged $importedCount new entries from backup'
              : 'Successfully restored ${entries.length} entries from backup';

          ScaffoldMessenger.of(scaffoldContext).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );

          widget.analyticsService.trackEvent('backup_restored', properties: {
            'merge_mode': mergeData,
            'entries_count': importedCount,
          });
        }
      } else {
        if (scaffoldContext.mounted) {
          Navigator.pop(scaffoldContext); // Close progress dialog

          ScaffoldMessenger.of(scaffoldContext).showSnackBar(
            SnackBar(
              content: const Text('Failed to restore backup'),
              backgroundColor: theme.colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (scaffoldContext.mounted) {
        Navigator.pop(scaffoldContext); // Close progress dialog

        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
          SnackBar(
            content: Text('Error restoring backup: ${e.toString()}'),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  String _formatBackupDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      final hours = diff.inHours;
      final minutes = diff.inMinutes;
      if (hours > 0) return '$hours hour${hours == 1 ? '' : 's'} ago';
      if (minutes > 0) return '$minutes minute${minutes == 1 ? '' : 's'} ago';
      return 'Just now';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} week${(diff.inDays / 7).floor() == 1 ? '' : 's'} ago';

    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildDeleteItem(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.close_rounded,
            size: 16,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(ThemeData theme) {
    return Container(
      key: widget.aboutKey,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_rounded,
                size: 24,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(
                'About',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Self Sync',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Version ${AppConstants.appVersion}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Track your mood, understand your patterns, nurture your well-being.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openBugReportScreen(context),
              icon: const Icon(Icons.bug_report_rounded),
              label: const Text('Report a Bug'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}