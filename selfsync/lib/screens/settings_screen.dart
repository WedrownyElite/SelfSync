// ignore_for_file: unused_field
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  final ImagePicker _imagePicker = ImagePicker();

  bool _isColorThemeExpanded = false;

  @override
  void initState() {
    super.initState();
    widget.themeService.addListener(_onThemeChanged);
    widget.analyticsService.addListener(_onAnalyticsChanged);
    widget.cloudBackupService.addListener(_onCloudBackupChanged);
    widget.authService.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    widget.themeService.removeListener(_onThemeChanged);
    widget.analyticsService.removeListener(_onAnalyticsChanged);
    widget.cloudBackupService.removeListener(_onCloudBackupChanged);
    widget.authService.removeListener(_onAuthChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    // If user is no longer signed in, close settings screen
    if (!widget.authService.isSignedIn && mounted) {
      AppLogger.info('User signed out, closing settings screen', tag: 'SettingsScreen');
      Navigator.of(context).pop();
    }
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
    final isAnonymous = widget.authService.isAnonymous;
    final hasGoogle = widget.authService.hasGoogleProvider;
    final hasEmail = widget.authService.hasEmailProvider;

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
// Profile Picture with tap to upload
                GestureDetector(
                  onTap: !isAnonymous  // CHANGED: removed && !hasGoogle condition
                      ? () => _showProfilePictureOptions(theme)
                      : null,
                  child: Stack(
                    children: [
                      if (user.photoURL != null && !isAnonymous)
                        CircleAvatar(
                          radius: 32,
                          backgroundImage: NetworkImage(user.photoURL!),
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                        )
                      else
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                          child: Icon(
                            isAnonymous ? Icons.person_off_rounded : Icons.person_rounded,
                            color: theme.colorScheme.primary,
                            size: 32,
                          ),
                        ),

                      // Camera icon overlay for all signed-in users (except anonymous)
                      if (!isAnonymous)  // CHANGED: removed hasEmail && !hasGoogle condition
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.surface,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              size: 16,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isAnonymous)
                        Text(
                          'Anonymous User',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else ...[
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

                        // Show Google linked status
                        if (hasGoogle)
                          Row(
                            children: [
                              Icon(
                                Icons.link_rounded,
                                size: 14,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Linked with Google',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Anonymous user: Show warning and conversion options
            if (isAnonymous) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_rounded,
                      size: 20,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your data is NOT backed up and will be lost if you uninstall the app or clear data.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_upload_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Create an account to enable cloud backups and sync your data across devices',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _showConvertAnonymousDialog(theme),
                  icon: const Icon(Icons.person_add_rounded),
                  label: const Text('Create Account & Enable Backups'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ]
            // Email user without Google: Show link Google option
            else if (hasEmail && !hasGoogle) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _handleLinkGoogle(theme),
                  icon: Image.asset(
                    'assets/google_logo.png',
                    height: 20,
                    width: 20,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.link_rounded, size: 20);
                    },
                  ),
                  label: const Text('Link Google Account'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildPrivacyToggle(
                theme: theme,
                title: 'Automatic Cloud Backups',
                description: 'Automatically backup your mood data to the cloud',
                value: widget.cloudBackupService.autoBackupEnabled,
                onChanged: (value) async {
                  await widget.cloudBackupService.setAutoBackupEnabled(value);

                  if (value && mounted) {
                    final entries = widget.moodService.getAllEntries();
                    await widget.cloudBackupService.backupToCloud(entries);

                    if (mounted) {
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
            ]
            // Email user with Google: Show unlink option and backup toggle
            else if (hasEmail && hasGoogle) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _handleUnlinkGoogle(theme),
                    icon: const Icon(Icons.link_off_rounded),
                    label: const Text('Unlink Google Account'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildPrivacyToggle(
                  theme: theme,
                  title: 'Automatic Cloud Backups',
                  description: 'Automatically backup your mood data to the cloud',
                  value: widget.cloudBackupService.autoBackupEnabled,
                  onChanged: (value) async {
                    await widget.cloudBackupService.setAutoBackupEnabled(value);

                    if (value && mounted) {
                      final entries = widget.moodService.getAllEntries();
                      await widget.cloudBackupService.backupToCloud(entries);

                      if (mounted) {
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
              ]
              // Google only user: Show backup toggle
              else ...[
                  _buildPrivacyToggle(
                    theme: theme,
                    title: 'Automatic Cloud Backups',
                    description: 'Automatically backup your mood data to the cloud',
                    value: widget.cloudBackupService.autoBackupEnabled,
                    onChanged: (value) async {
                      await widget.cloudBackupService.setAutoBackupEnabled(value);

                      if (value && mounted) {
                        final entries = widget.moodService.getAllEntries();
                        await widget.cloudBackupService.backupToCloud(entries);

                        if (mounted) {
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
                ],

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

  void _showProfilePictureOptions(ThemeData theme) {
    final user = widget.authService.currentUser;
    final hasGoogle = widget.authService.hasGoogleProvider;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickProfilePicture(ImageSource.gallery, theme);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _pickProfilePicture(ImageSource.camera, theme);
              },
            ),
            if (user?.photoURL != null)
              ListTile(
                leading: Icon(Icons.delete_rounded, color: theme.colorScheme.error),
                title: Text(
                  'Remove custom photo',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _removeProfilePicture(theme);
                },
              ),
            // Add option to restore Google photo if user has Google linked
            if (hasGoogle && user?.photoURL != null)
              ListTile(
                leading: const Icon(Icons.restore_rounded),
                title: const Text('Restore Google photo'),
                onTap: () {
                  Navigator.pop(context);
                  _restoreGoogleProfilePicture(theme);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _restoreGoogleProfilePicture(ThemeData theme) async {
    // Show confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Google Photo?'),
        content: const Text('This will replace your custom profile picture with your Google account photo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // Capture context references
    final messenger = ScaffoldMessenger.of(context);

    // Show progress
    showDialog(
      context: context,
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
                    theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Restoring Google photo...',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final success = await widget.authService.restoreGoogleProfilePicture();

    if (mounted) {
      Navigator.pop(context); // Close progress dialog

      messenger.showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Google photo restored'
              : 'Failed to restore Google photo'),
          backgroundColor: success ? Colors.green : theme.colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickProfilePicture(ImageSource source, ThemeData theme) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );

      if (image == null) return;

      // Crop the image with circular overlay
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Picture',
            toolbarColor: theme.colorScheme.primary,
            toolbarWidgetColor: theme.colorScheme.onPrimary,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            backgroundColor: theme.colorScheme.surface,
            activeControlsWidgetColor: theme.colorScheme.primary,
            cropFrameColor: theme.colorScheme.primary,
            cropGridColor: theme.colorScheme.primary.withValues(alpha: 0.5),
            hideBottomControls: false,
            cropFrameStrokeWidth: 4,
            cropStyle: CropStyle.circle,  // Circular crop for Android
          ),
          IOSUiSettings(
            title: 'Crop Profile Picture',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            cropStyle: CropStyle.circle,  // Circular crop for iOS
          ),
        ],
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      );

      if (croppedFile == null) {
        AppLogger.info('User cancelled image cropping', tag: 'SettingsScreen');
        return;
      }

      if (!mounted) return;

      // Capture context references before async gap
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);

      // Show uploading progress
      showDialog(
        context: context,
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
                      theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Uploading profile picture...',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Upload to Firebase Storage and update profile
      final photoURL = await widget.authService.uploadAndUpdateProfilePicture(croppedFile.path);

      if (mounted) {
        navigator.pop(); // Close progress dialog

        messenger.showSnackBar(
          SnackBar(
            content: Text(photoURL != null
                ? 'Profile picture updated'
                : 'Failed to update profile picture'),
            backgroundColor: photoURL != null ? Colors.green : theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Failed to pick profile picture: $e', tag: 'SettingsScreen');

      // Close progress dialog if it's showing
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update profile picture'),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _removeProfilePicture(ThemeData theme) async {
    // Show confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Profile Picture?'),
        content: const Text('Are you sure you want to remove your profile picture?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // Capture context references BEFORE async gap
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Show progress
    showDialog(
      context: context,
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
                    theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Removing profile picture...',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final success = await widget.authService.deleteProfilePicture();

    if (mounted) {
      navigator.pop(); // Close progress dialog

      messenger.showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Profile picture removed'
              : 'Failed to remove profile picture'),
          backgroundColor: success ? Colors.green : theme.colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleUnlinkGoogle(ThemeData theme) async {
    // First, save current profile data before unlinking
    final user = widget.authService.currentUser;
    if (user == null) return;

    // Show confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlink Google Account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will unlink your Google account from Self Sync.'),
            const SizedBox(height: 12),
            const Text('You will still be able to sign in with your email and password.'),
            const SizedBox(height: 12),
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
                  const Expanded(
                    child: Text(
                      'Your custom profile picture will be restored if you had one.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // Capture ScaffoldMessenger BEFORE any async gaps
    final messenger = ScaffoldMessenger.of(context);

    // Get user ID for profile storage
    final userId = user.uid;

    // Check if user has a custom profile picture stored
    final prefs = await SharedPreferences.getInstance();
    final savedPhotoURL = prefs.getString('profile_picture_$userId');
    final savedDisplayName = prefs.getString('display_name_$userId');

    try {
      final success = await widget.authService.unlinkGoogleAccount();

      if (success) {
        // Restore saved profile data if it exists
        if (savedPhotoURL != null && savedPhotoURL.isNotEmpty) {
          await widget.authService.updateProfilePicture(savedPhotoURL);
        }

        if (savedDisplayName != null && savedDisplayName.isNotEmpty) {
          await widget.authService.updateDisplayName(savedDisplayName);
        }

        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Google account unlinked successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(widget.authService.getAuthErrorMessage(e)),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showConvertAnonymousDialog(ThemeData theme) {
    final entries = widget.moodService.getAllEntries();
    final hasData = entries.isNotEmpty;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasData) ...[
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
                        'You have ${entries.length} mood ${entries.length == 1 ? "entry" : "entries"}. Your data will be merged with your new account.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text('Choose how you\'d like to create your account:'),
            const SizedBox(height: 16),

            // Email/Password option
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showEmailAccountChoiceDialog(theme);
                },
                icon: const Icon(Icons.email_rounded),
                label: const Text('Email & Password'),
              ),
            ),
            const SizedBox(height: 12),

            // Google option
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await _convertAnonymousToGoogleWithConfirmation(theme);
                },
                icon: Image.asset(
                  'assets/google_logo.png',
                  height: 20,
                  width: 20,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.login_rounded, size: 20);
                  },
                ),
                label: const Text('Google Account'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _convertAnonymousToGoogleWithConfirmation(ThemeData theme) async {
    final entries = widget.moodService.getAllEntries();
    final hasData = entries.isNotEmpty;

    if (hasData) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Link Google Account?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This will link your Google account to Self Sync.'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.merge_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your ${entries.length} mood ${entries.length == 1 ? "entry" : "entries"} will be kept in your Google account.',
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
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Link & Keep Data'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    // Proceed with Google conversion
    await _convertAnonymousToGoogle(theme);
  }

  void _showEmailAccountChoiceDialog(ThemeData theme) {
    final entries = widget.moodService.getAllEntries();
    final hasData = entries.isNotEmpty;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Email & Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasData) ...[
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
                        'You have ${entries.length} mood ${entries.length == 1 ? "entry" : "entries"}.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text('Would you like to:'),
            const SizedBox(height: 16),

            // Sign in to existing account
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showEmailSignInDialog(theme);
                },
                icon: const Icon(Icons.login_rounded),
                label: Text(hasData
                    ? 'Sign in & merge data'
                    : 'Sign in to existing account'),
              ),
            ),
            const SizedBox(height: 12),

            // Create new account
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showEmailRegistrationDialog(theme);
                },
                icon: const Icon(Icons.person_add_rounded),
                label: const Text('Create new account'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showEmailSignInDialog(ThemeData theme) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Sign In'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                      ),
                      onPressed: () {
                        setState(() => obscurePassword = !obscurePassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  await _convertAnonymousWithSignIn(
                    emailController.text.trim(),
                    passwordController.text,
                    theme,
                  );
                }
              },
              child: const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmailRegistrationDialog(ThemeData theme) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Account'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name (optional)',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                        onPressed: () {
                          setState(() => obscurePassword = !obscurePassword);
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: Icon(Icons.lock_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  await _convertAnonymousToEmail(
                    emailController.text.trim(),
                    passwordController.text,
                    nameController.text.trim().isNotEmpty
                        ? nameController.text.trim()
                        : null,
                    theme,
                  );
                }
              },
              child: const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _convertAnonymousWithSignIn(
      String email,
      String password,
      ThemeData theme,
      ) async {
    final messenger = mounted ? ScaffoldMessenger.of(context) : null;

    try {
      // Get current anonymous user's data
      final anonymousEntries = widget.moodService.getAllEntries();

      // Sign in to existing account
      final success = await widget.authService.signInWithEmail(email, password);

      if (success && anonymousEntries.isNotEmpty) {
        // Merge anonymous data with signed-in account
        for (final entry in anonymousEntries) {
          widget.moodService.importEntry(entry);
        }

        if (mounted && messenger != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Signed in successfully! Merged ${anonymousEntries.length} entries.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (success && mounted && messenger != null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Signed in successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (!success && mounted && messenger != null) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Failed to sign in'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted && messenger != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(widget.authService.getAuthErrorMessage(e)),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _convertAnonymousToEmail(
      String email,
      String password,
      String? name,
      ThemeData theme,
      ) async {
    try {
      final success = await widget.authService.convertAnonymousToEmail(
        email,
        password,
        displayName: name,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Account created successfully!'
                : 'Failed to create account'),
            backgroundColor: success ? Colors.green : theme.colorScheme.error,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.authService.getAuthErrorMessage(e)),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _convertAnonymousToGoogle(ThemeData theme) async {
    try {
      final success = await widget.authService.convertAnonymousToGoogle();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Account linked successfully!'
                : 'Failed to link account'),
            backgroundColor: success ? Colors.green : theme.colorScheme.error,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.authService.getAuthErrorMessage(e)),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleLinkGoogle(ThemeData theme) async {
    final entries = widget.moodService.getAllEntries();
    final hasData = entries.isNotEmpty;

    // Show confirmation if user has data
    if (hasData) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Link Google Account?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This will link your Google account to Self Sync.'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.merge_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your ${entries.length} mood ${entries.length == 1 ? "entry" : "entries"} will be merged with your Google account.',
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
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Link & Merge'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    // Proceed with linking
    await _performGoogleLink(theme);
  }

  Future<void> _performGoogleLink(ThemeData theme) async {
    // Save current profile data before linking
    final user = widget.authService.currentUser;
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();

      // Save current custom profile picture URL if it exists
      if (user.photoURL != null &&
          user.photoURL!.isNotEmpty &&
          user.photoURL!.contains('firebase')) {
        await prefs.setString('profile_picture_${user.uid}', user.photoURL!);
        AppLogger.info('Saved custom profile picture before linking Google', tag: 'SettingsScreen');
      }

      // Save current display name
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        await prefs.setString('display_name_${user.uid}', user.displayName!);
      }
    }

    final messenger = mounted ? ScaffoldMessenger.of(context) : null;

    try {
      final success = await widget.authService.linkGoogleAccount();

      if (mounted && messenger != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Google account linked successfully!'
                : 'Failed to link Google account'),
            backgroundColor: success ? Colors.green : theme.colorScheme.error,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted && messenger != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(widget.authService.getAuthErrorMessage(e)),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    }
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
    final selectedGradient = widget.themeService.selectedGradient;
    final themeName = _getGradientName(selectedGradient);

    return Container(
      key: widget.colorThemesKey,
      clipBehavior: Clip.antiAlias,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tappable header
          InkWell(
            onTap: () {
              setState(() {
                _isColorThemeExpanded = !_isColorThemeExpanded;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
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
                          _isColorThemeExpanded
                              ? 'Changes your mood rating colors'
                              : themeName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Gradient preview (visible when collapsed)
                  if (!_isColorThemeExpanded) ...[
                    Container(
                      width: 40,
                      height: 24,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: selectedGradient.colors.gradientColors,
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Animated chevron
                  AnimatedRotation(
                    turns: _isColorThemeExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expandable content
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: ColorGradientOption.values.map((gradient) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildColorOption(theme: theme, gradient: gradient),
                  );
                }).toList(),
              ),
            ),
            crossFadeState: _isColorThemeExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  String _getGradientName(ColorGradientOption gradient) {
    switch (gradient) {
      case ColorGradientOption.purpleBlue:
        return 'Purple Dream';
      case ColorGradientOption.sunsetOrange:
        return 'Sunset Glow';
      case ColorGradientOption.oceanTeal:
        return 'Ocean Breeze';
      case ColorGradientOption.forestGreen:
        return 'Forest Calm';
      case ColorGradientOption.rosePink:
        return 'Rose Garden';
      case ColorGradientOption.goldenAmber:
        return 'Golden Hour';
      case ColorGradientOption.arcticBlue:
        return 'Arctic Frost';
      case ColorGradientOption.lavenderMist:
        return 'Lavender Mist';
    }
  }

  Widget _buildColorOption({
    required ThemeData theme,
    required ColorGradientOption gradient,
  }) {
    final isSelected = widget.themeService.selectedGradient == gradient;
    final themeName = _getGradientName(gradient);

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
        child: StatefulBuilder(
          builder: (context, setState) {
            // Check keyboard visibility
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final isKeyboardVisible = bottomInset > 0;

            return AlertDialog(
              contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              icon: AnimatedScale(
                scale: isKeyboardVisible ? 0.7 : 1.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: Icon(
                  Icons.warning_rounded,
                  color: theme.colorScheme.error,
                  size: 48,
                ),
              ),
              title: AnimatedScale(
                scale: isKeyboardVisible ? 0.85 : 1.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: const Text('Delete Account?'),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // Wrap list items in AnimatedCrossFade
                    AnimatedCrossFade(
                      firstChild: Column(
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
                        ],
                      ),
                      secondChild: const SizedBox(height: 8),
                      crossFadeState: isKeyboardVisible
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 300),
                    ),

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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (value) {
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // Dismiss keyboard first
                    FocusScope.of(dialogContext).unfocus();

                    // Close dialog immediately
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: confirmController,
                  builder: (context, value, child) {
                    final isDeleteTyped = value.text.trim().toUpperCase() == 'DELETE';

                    return FilledButton(
                      onPressed: isDeleteTyped ? () async {
                        // Dismiss keyboard first
                        FocusScope.of(dialogContext).unfocus();

                        // Small delay to let keyboard close
                        await Future.delayed(const Duration(milliseconds: 150));

                        // Close dialog
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }

                        // Show confirmation after dialog is closed
                        await Future.delayed(const Duration(milliseconds: 100));
                        if (context.mounted) {
                          _performAccountDeletion(context, theme);
                        }
                      } : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                        disabledBackgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                        disabledForegroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.38),
                      ),
                      child: const Text('Delete Account'),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    ).then((_) {
      // Dispose controller AFTER dialog is completely closed and animations are done
      if (!isDisposed) {
        // Use a longer delay to ensure all animations have completed
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!isDisposed) {
            try {
              confirmController.dispose();
              isDisposed = true;
            } catch (e) {
              // Already disposed or still in use, ignore
              AppLogger.warning('Controller disposal caught: $e', tag: 'SettingsScreen');
            }
          }
        });
      }
    });
  }

  Future<void> _performAccountDeletion(BuildContext context, ThemeData theme) async {
    // Capture a navigator key before showing dialog
    final navigator = Navigator.of(context);

    // Show progress
    showDialog(
      context: context,
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

    // Reset backup preferences - ADD THIS
    await widget.cloudBackupService.resetBackupPreferences();

    // Try to delete Firebase account
    bool accountDeleted = false;
    bool needsReauth = false;
    String? errorMessage;

    try {
      accountDeleted = await widget.authService.deleteAccount();
    } on FirebaseAuthException catch (e) {
      AppLogger.info('Firebase auth exception: ${e.code}', tag: 'SettingsScreen');

      if (e.code == 'requires-recent-login') {
        needsReauth = true;
        AppLogger.info('Setting needsReauth to true', tag: 'SettingsScreen');
      } else {
        errorMessage = widget.authService.getAuthErrorMessage(e);
      }
    } catch (e) {
      AppLogger.error('Unexpected error during account deletion: $e', tag: 'SettingsScreen');
      errorMessage = 'An unexpected error occurred. Please try again.';
    }

    // Close progress dialog IMMEDIATELY
    if (navigator.canPop()) {
      navigator.pop();
    }

    AppLogger.info('After progress dialog close - needsReauth: $needsReauth, accountDeleted: $accountDeleted', tag: 'SettingsScreen');

    if (needsReauth) {
      AppLogger.info('Handling reauth requirement', tag: 'SettingsScreen');

      // Reset onboarding state so they see privacy policy on next sign-in
      await widget.onboardingService.resetAll();

      // Perform complete sign-out including Google
      await widget.authService.completeSignOut();

      // Navigate back
      if (navigator.canPop()) {
        navigator.pop();
      }
    } else if (accountDeleted) {
      AppLogger.success('Account deleted successfully', tag: 'SettingsScreen');
      widget.analyticsService.trackEvent('account_deleted');

      // CRITICAL: Reset ALL app state for new user experience
      AppLogger.info('Resetting all app state...', tag: 'SettingsScreen');

      // Reset onboarding state
      await widget.onboardingService.resetAll();

      // Reset cloud backup settings (already done above)
      await widget.cloudBackupService.setAutoBackupEnabled(false);

      // Perform complete sign-out (including Google)
      await widget.authService.completeSignOut();

      // Close settings immediately
      if (navigator.canPop()) {
        navigator.pop();
      }

      AppLogger.success('Account deletion and cleanup complete', tag: 'SettingsScreen');
    } else {
      AppLogger.info('Showing error message: $errorMessage', tag: 'SettingsScreen');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage ?? 'Failed to delete account. Please try again.'),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
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