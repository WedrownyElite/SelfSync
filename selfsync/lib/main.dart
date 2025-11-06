import 'dart:math';
import 'package:flutter/material.dart';
import 'utils/app_logger.dart';
import 'utils/performance_test_helper.dart';
import 'screens/calendar_screen.dart';
import 'screens/mood_log_screen.dart';
import 'screens/trends_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/help_screen.dart';
import 'services/mood_service.dart';
import 'services/theme_service.dart';
import 'services/onboarding_service.dart';
import 'services/analytics_service.dart';
import 'widgets/modern_nav_bar.dart';
import 'widgets/side_drawer.dart';
import 'widgets/interactive_tutorial_overlay.dart';
import 'widgets/privacy_policy_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final startTime = DateTime.now();
  AppLogger.separator(label: 'SELF SYNC APP STARTUP');
  AppLogger.lifecycle('App starting...', tag: 'Main');

  final analyticsService = AnalyticsService();

  FlutterError.onError = (FlutterErrorDetails details) {
    analyticsService.logFlutterError(details);
  };

  runApp(SelfSyncApp(
    analyticsService: analyticsService,
    startTime: startTime,
  ));

  AppLogger.lifecycle('App launched successfully', tag: 'Main');
  AppLogger.separator();
}

class SelfSyncApp extends StatefulWidget {
  final AnalyticsService analyticsService;
  final DateTime startTime;

  const SelfSyncApp({
    super.key,
    required this.analyticsService,
    required this.startTime,
  });

  @override
  State<SelfSyncApp> createState() => _SelfSyncAppState();
}

class _SelfSyncAppState extends State<SelfSyncApp> {
  late final ThemeService _themeService;
  late final OnboardingService _onboardingService;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService();
    _onboardingService = OnboardingService();

    _themeService.addListener(_onThemeChanged);
    _onboardingService.addListener(_onOnboardingChanged);

    _trackStartupTime();
    _waitForInitialization();
  }

  void _trackStartupTime() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final duration = DateTime.now().difference(widget.startTime);
      widget.analyticsService.trackAppStartup(duration);
      AppLogger.performance('App startup took ${duration.inMilliseconds}ms');
    });
  }

  Future<void> _waitForInitialization() async {
    await Future.delayed(const Duration(milliseconds: 100));
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    _onboardingService.removeListener(_onOnboardingChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  void _onOnboardingChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.lifecycle('Building SelfSyncApp widget', tag: 'SelfSyncApp');

    if (!_isInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                _themeService.selectedGradient.colors.primary,
              ),
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'Self Sync',
      debugShowCheckedModeBanner: false,
      theme: _themeService.getLightTheme(),
      darkTheme: _themeService.getDarkTheme(),
      themeMode: _themeService.themeMode,
      home: MainScreen(
        themeService: _themeService,
        analyticsService: widget.analyticsService,
        onboardingService: _onboardingService,
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final ThemeService themeService;
  final AnalyticsService analyticsService;
  final OnboardingService onboardingService;

  const MainScreen({
    super.key,
    required this.themeService,
    required this.analyticsService,
    required this.onboardingService,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 1;
  late final MoodService _moodService;
  late final SideDrawerController _drawerController;
  DateTime? _targetDate;

  late final CalendarScreen _calendarScreen;
  late final TrendsScreen _trendsScreen;

  final GlobalKey _calendarTabKey = GlobalKey();
  final GlobalKey _diaryTabKey = GlobalKey();
  final GlobalKey _trendsTabKey = GlobalKey();

  // Tutorial keys for MoodLogScreen
  final GlobalKey _tutorialTextFieldKey = GlobalKey();
  final GlobalKey _tutorialSliderKey = GlobalKey();
  final GlobalKey _tutorialSendButtonKey = GlobalKey();
  final GlobalKey _tutorialCalendarExpandKey = GlobalKey();

  final GlobalKey<MoodLogScreenState> _moodLogKey = GlobalKey<MoodLogScreenState>();

  // Track if onboarding is active to block navigation
  bool _isOnboardingActive = false;
  int _onboardingStep = 0;

  // Tutorial keys for TrendsScreen  
  final GlobalKey _tutorialTrendsDatePresetsKey = GlobalKey();
  final GlobalKey _tutorialTrendsInsightsKey = GlobalKey();
  final GlobalKey _tutorialTrendsComparisonKey = GlobalKey();
  final GlobalKey _tutorialTrendsStreakKey = GlobalKey();
  final GlobalKey _tutorialTrendsAverageMoodKey = GlobalKey();
  final GlobalKey _tutorialTrendsPeakTimeKey = GlobalKey();
  final GlobalKey _tutorialTrendsConsistencyKey = GlobalKey();
  final GlobalKey _tutorialTrendsBestDayKey = GlobalKey();
  final GlobalKey _tutorialTrendsToughestDayKey = GlobalKey();
  final GlobalKey _tutorialTrendsMoodChartKey = GlobalKey();
  final GlobalKey _tutorialTrendsDistributionKey = GlobalKey();
  final GlobalKey _tutorialTrendsActivityKey = GlobalKey();

  final GlobalKey<CalendarScreenState> _calendarKey = GlobalKey<CalendarScreenState>();
  final GlobalKey<TrendsScreenState> _trendsKey = GlobalKey<TrendsScreenState>();

  // Tutorial keys for CalendarScreen  
  final GlobalKey _tutorialCalendarViewToggleKey = GlobalKey();

  // Tutorial keys for side drawer
  final GlobalKey _hamburgerMenuKey = GlobalKey();
  final GlobalKey _drawerSettingsKey = GlobalKey();
  final GlobalKey _drawerHelpKey = GlobalKey();

  // Tutorial keys for Settings screen
  final GlobalKey _settingsThemeModesKey = GlobalKey();
  final GlobalKey _settingsColorThemesKey = GlobalKey();
  final GlobalKey _settingsPrivacyKey = GlobalKey();
  final GlobalKey _settingsAboutKey = GlobalKey();

  // Tutorial keys for Help screen
  final GlobalKey _helpContentKey = GlobalKey();

  // Screen state keys
  final GlobalKey<SettingsScreenState> _settingsKey = GlobalKey<SettingsScreenState>();
  final GlobalKey<HelpScreenState> _helpKey = GlobalKey<HelpScreenState>();

  bool _hasGeneratedFakeData = false;
  final List<String> _fakeDataEntryIds = [];

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('MainScreen initialized', tag: 'MainScreen');

    _moodService = MoodService();
    _drawerController = SideDrawerController();

    // Listen to drawer state changes for onboarding progression
    _drawerController.addListener(_onDrawerStateChanged);

    _calendarScreen = CalendarScreen(
      key: _calendarKey,
      moodService: _moodService,
      onDateSelected: (date) => _navigateToDate(1, date),
      drawerController: _drawerController,
      themeService: widget.themeService,
      viewToggleKey: _tutorialCalendarViewToggleKey,
      hamburgerKey: _hamburgerMenuKey,
    );

    _trendsScreen = TrendsScreen(
      key: _trendsKey,
      moodService: _moodService,
      drawerController: _drawerController,
      themeService: widget.themeService,
      datePresetsKey: _tutorialTrendsDatePresetsKey,
      insightsKey: _tutorialTrendsInsightsKey,
      comparisonKey: _tutorialTrendsComparisonKey,
      streakKey: _tutorialTrendsStreakKey,
      averageMoodKey: _tutorialTrendsAverageMoodKey,
      peakTimeKey: _tutorialTrendsPeakTimeKey,
      consistencyKey: _tutorialTrendsConsistencyKey,
      bestDayKey: _tutorialTrendsBestDayKey,
      toughestDayKey: _tutorialTrendsToughestDayKey,
      moodChartKey: _tutorialTrendsMoodChartKey,
      distributionKey: _tutorialTrendsDistributionKey,
      activityKey: _tutorialTrendsActivityKey,
      hamburgerKey: _hamburgerMenuKey,
    );

    widget.analyticsService.trackScreenView(_getTabName(_currentIndex));

    if (!widget.onboardingService.privacyAccepted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPrivacyPolicy();
      });
    } else if (widget.onboardingService.shouldShowTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _showTutorial();
          }
        });
      });
    }
  }

  void _showPrivacyPolicy() {
    AppLogger.info('Showing privacy policy dialog', tag: 'MainScreen');
    widget.analyticsService.trackEvent('privacy_policy_shown');

    PrivacyPolicyController.show(
      context,
      onAccept: () async {
        await widget.onboardingService.acceptPrivacyPolicy();
        widget.analyticsService.trackEvent('privacy_policy_accepted');

        if (mounted) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _showTutorial();
            }
          });
        }
      },
      onDecline: () {
        widget.analyticsService.trackEvent('privacy_policy_declined');
        AppLogger.warning('User declined privacy policy', tag: 'MainScreen');
      },
    );
  }

  void _showTutorial() {
    AppLogger.info('Starting onboarding', tag: 'MainScreen');
    widget.analyticsService.trackEvent('tutorial_started');

    setState(() {
      _currentIndex = 1;
      _isOnboardingActive = true;
      _onboardingStep = 0;
    });

    // Start onboarding mode in MoodLogScreen
    Future.delayed(const Duration(milliseconds: 100), () {
      _moodLogKey.currentState?.startOnboarding();
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;

      final steps = [
        OnboardingStep(
          title: 'Welcome to Self Sync! 👋',
          description: 'Track your daily moods and discover patterns in your emotional well-being. Let\'s learn how to log your first mood entry!',
          actionHint: 'Tap to begin',
          requiresAction: false,
          centerCard: true,
          showOverlay: false,
        ),
        OnboardingStep(
          title: 'Add a Mood Entry',
          description: 'This text box is where you can type notes about how you\'re feeling. Tap anywhere to continue!',
          targetKey: _tutorialTextFieldKey,
          actionHint: 'Tap to continue',
          requiresAction: false,
        ),
        OnboardingStep(
          title: 'Rate Your Mood',
          description: 'Drag the slider to rate how you\'re feeling from 1 (struggling) to 10 (excellent). Watch the emoji change as you move it!',
          targetKey: _tutorialSliderKey,
          actionHint: 'Move the slider',
          requiresAction: true,
          forceTopPosition: true,
        ),
        OnboardingStep(
          title: 'Save Your Entry',
          description: 'Perfect! Now tap the send button to save your first mood entry.',
          targetKey: _tutorialSendButtonKey,
          actionHint: 'Tap the send button',
          requiresAction: true,
        ),
        OnboardingStep(
          title: 'Edit & Delete Entries',
          description: 'You can edit or delete any entry. Try it now: swipe right on the entry you just created, or long-press it to see options.',
          actionHint: 'Swipe or hold an entry',
          requiresAction: true,
        ),
        OnboardingStep(
          title: 'Calendar Filter 📅',
          description: 'Tap the down arrow at the top to expand the calendar and filter your entries by date.',
          targetKey: _tutorialCalendarExpandKey,
          actionHint: 'Tap the arrow',
          requiresAction: true,
        ),
        OnboardingStep(
          title: 'Using the Calendar',
          description: 'Select a single date to view entries from that day, or tap two dates to view everything in between! Try it out.',
          actionHint: 'Tap to continue',
          requiresAction: false,
          showOverlay: false,
        ),
        OnboardingStep(
          title: 'Close the Calendar',
          description: 'When you\'re done, tap the up arrow to close the calendar and return to your diary.',
          targetKey: _tutorialCalendarExpandKey,
          actionHint: 'Tap the arrow to close',
          requiresAction: true,
          showOverlay: false,
        ),
        OnboardingStep(
          title: 'Explore the Calendar 📅',
          description: 'Let\'s check out the Calendar view to see your moods at a glance. Tap the Calendar tab at the bottom of the screen.',
          targetKey: _calendarTabKey,
          actionHint: 'Tap the Calendar tab',
          requiresAction: true,
        ),
        OnboardingStep(
          title: 'Calendar View Options',
          description: 'You can customize how you view your calendar! Tap the View Options button to explore different layouts.',
          targetKey: _tutorialCalendarViewToggleKey,
          actionHint: 'Tap View Options',
          requiresAction: true,
          forceTopPosition: true,
        ),
        // STEP 10
        OnboardingStep(
          title: 'Discover Trends 📊',
          description: 'Now let\'s explore your mood analytics! We\'ll load some sample data so you can see all the features in action. Tap the Trends tab!',
          targetKey: _trendsTabKey,
          actionHint: 'Tap the Trends tab',
          requiresAction: true,
        ),
        // STEP 11 - Date Range (NO SCROLL, just spotlight)
        OnboardingStep(
          title: 'Date Range Selection',
          description: 'Great! The sample data is loaded. Use these buttons to view trends over different time periods - from 7 days to your entire history!',
          targetKey: _tutorialTrendsDatePresetsKey,
          actionHint: 'Try tapping a date range',
          requiresAction: true,
        ),
        // STEP 12 - Insights (NO SCROLL, just spotlight)
        OnboardingStep(
          title: 'Insights Card 💡',
          description: 'Get personalized insights based on your mood patterns. We analyze your data to provide helpful observations!',
          targetKey: _tutorialTrendsInsightsKey,
          actionHint: 'Tap to continue',
          requiresAction: false,
        ),
        // STEP 13 - Period Comparison (NO SCROLL, just spotlight)
        OnboardingStep(
          title: 'Period Comparison 📊',
          description: 'See how your current mood compares to previous periods. Track your progress over time!',
          targetKey: _tutorialTrendsComparisonKey,
          actionHint: 'Tap to continue',
          requiresAction: false,
        ),
        // STEP 14 - Current Streak (SCROLL, then spotlight)
        OnboardingStep(
          title: 'Streak Counter 🔥',
          description: 'Track your logging consistency! Your current streak shows how many consecutive days you\'ve logged, while best streak shows your record.',
          targetKey: _tutorialTrendsStreakKey,
          actionHint: 'Tap to continue',
          requiresAction: false,
        ),
        // STEP 15 - Average Mood (NO SCROLL, just spotlight)
        OnboardingStep(
          title: 'Average Mood',
          description: 'This shows your average mood rating for the selected time period. A higher number means better overall mood!',
          targetKey: _tutorialTrendsAverageMoodKey,
          actionHint: 'Tap to continue',
          requiresAction: false,
        ),
        // STEP 16 - Peak Time (SCROLL, then spotlight)
        OnboardingStep(
          title: 'Peak Time',
          description: 'Discover what time of day you typically feel your best. Use this to plan important activities during your peak hours!',
          targetKey: _tutorialTrendsPeakTimeKey,
          actionHint: 'Tap to continue',
          requiresAction: false,
        ),
        // STEP 17 - Consistency (NO SCROLL, just spotlight)
        OnboardingStep(
          title: 'Mood Consistency',
          description: 'See how stable your moods are over time. Higher consistency means fewer mood swings.',
          targetKey: _tutorialTrendsConsistencyKey,
          actionHint: 'Tap to continue',
          requiresAction: false,
        ),
        // STEP 18 - Best Day (SCROLL, then spotlight)
        OnboardingStep(
          title: 'Best Day',
          description: 'Your highest mood day in this period. Tap to jump to that entry in your diary!',
          targetKey: _tutorialTrendsBestDayKey,
          actionHint: 'Tap to continue',
          requiresAction: false,
        ),
        // STEP 19 - Toughest Day (NO SCROLL, just spotlight)
        OnboardingStep(
          title: 'Toughest Day',
          description: 'Your lowest mood day. Understanding tough days helps identify triggers and patterns.',
          targetKey: _tutorialTrendsToughestDayKey,
          actionHint: 'Tap to continue',
          requiresAction: false,
        ),
        // STEP 20 - Chart (SCROLL ONLY, NO spotlight)
        OnboardingStep(
          title: 'Mood Trend Chart 📈',
          description: 'This chart visualizes how your mood changes over time. Look for patterns, trends, and correlations with life events!',
          actionHint: 'Tap to continue',
          requiresAction: false,
          showOverlay: true,
        ),
        // STEP 21 - Distribution (SCROLL ONLY, NO spotlight)
        OnboardingStep(
          title: 'Mood Distribution',
          description: 'See how often you experience different mood levels. Swipe to see different visualizations!',
          actionHint: 'Tap to continue',
          requiresAction: false,
          showOverlay: true,
        ),
        // STEP 22 - Activity (SCROLL ONLY, NO spotlight)
        OnboardingStep(
          title: 'Activity Heatmap',
          description: 'This calendar shows your logging activity. Darker colors mean more entries logged that day - aim for consistency!',
          actionHint: 'Tap to continue',
          requiresAction: false,
          showOverlay: true,
        ),
        // STEP 23 - Open Side Drawer
        OnboardingStep(
          title: 'Let\'s Explore Settings! ⚙️',
          description: 'Tap the menu button to open the side drawer and access Settings.',
          targetKey: _hamburgerMenuKey,
          actionHint: 'Tap the menu',
          requiresAction: true,
        ),
        // STEP 24 - Tap Settings
        OnboardingStep(
          title: 'Open Settings',
          description: 'Now tap Settings to customize your Self Sync experience!',
          targetKey: _drawerSettingsKey,
          actionHint: 'Tap Settings',
          requiresAction: true,
        ),
        // STEP 25 - Theme Modes (SCROLL + spotlight)
        OnboardingStep(
          title: 'Theme Mode 🌓',
          description: 'Choose between Light, Dark, or Auto theme mode. Auto switches based on your system settings!',
          targetKey: _settingsThemeModesKey,
          actionHint: 'Tap to continue',
          requiresAction: false,
        ),
        // STEP 26 - Color Themes (NO scroll, just spotlight)
        OnboardingStep(
          title: 'Color Themes 🎨',
          description: 'These colors affect your mood rating gradients. Pick your favorite palette!',
          targetKey: _settingsColorThemesKey,
          actionHint: 'Tap to continue',
          requiresAction: false,
        ),
        // STEP 27 - Privacy & Analytics (SCROLL + spotlight)
        OnboardingStep(
          title: 'Privacy & Analytics 🔒',
          description: 'Control your data sharing preferences. All mood data stays on your device - only anonymous usage stats are optional.',
          targetKey: _settingsPrivacyKey,
          actionHint: 'Tap to continue',
          requiresAction: false,
        ),
        // STEP 28 - About (NO scroll, just spotlight)
        OnboardingStep(
          title: 'About Self Sync 💜',
          description: 'Your personal mood tracking companion. Thanks for using Self Sync!',
          targetKey: _settingsAboutKey,
          actionHint: 'Tap to continue',
          requiresAction: false,
        ),
        // STEP 29 - Navigate Back & Open Drawer
        OnboardingStep(
          title: 'Check Out Help! 📚',
          description: 'Go back and open the menu again to explore the Help section with guides and tips.',
          targetKey: _hamburgerMenuKey,
          actionHint: 'Tap the menu',
          requiresAction: true,
        ),
        // STEP 30 - Tap Help
        OnboardingStep(
          title: 'Open Help & Support',
          description: 'Tap Help to browse guides, tips, and support options.',
          targetKey: _drawerHelpKey,
          actionHint: 'Tap Help',
          requiresAction: true,
        ),
        // STEP 31 - Help Content Preview (SCROLL only, NO spotlight)
        OnboardingStep(
          title: 'Browse Help Resources 📖',
          description: 'Here you\'ll find detailed guides, tips & tricks, and support options. Explore at your own pace!',
          actionHint: 'Tap to continue',
          requiresAction: false,
          showOverlay: true,
        ),
        // STEP 32 - All Done!
        OnboardingStep(
          title: 'You\'re All Set! 🎉',
          description: 'You\'ve completed the tutorial! Start tracking your moods consistently to unlock deeper insights into your emotional well-being.',
          actionHint: 'Tap to finish',
          requiresAction: false,
          centerCard: true,
        ),
      ];

      OnboardingController.start(
        context,
        steps: steps,
        onStepChanged: (stepIndex) {
          AppLogger.separator(label: 'STEP CHANGE');
          AppLogger.info('Onboarding step changed to: $stepIndex', tag: 'MainScreen');

          // Don't call setOnboardingStep for steps 14-19 yet - happens after scroll/delay
          if (stepIndex < 14 || stepIndex > 19) {
            _moodLogKey.currentState?.setOnboardingStep(stepIndex);
          }

          if (stepIndex == 2) {
            setState(() {
              _onboardingStep = stepIndex;
            });
            _expandMoodSlider();
          }

          // Steps 0-7 and 9: Update state immediately
          if ((stepIndex >= 0 && stepIndex <= 7) || stepIndex == 9) {
            setState(() {
              _onboardingStep = stepIndex;
            });
          }

          // Step 8: Calendar tab navigation - needs state update for navigation to work
          if (stepIndex == 8) {
            setState(() {
              _onboardingStep = stepIndex;
            });
          }

          if (stepIndex == 10) {
            setState(() {
              _onboardingStep = stepIndex;
            });
            _calendarKey.currentState?.endOnboarding();

            // Show loading message to user
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Loading sample mood data for demonstration...'),
                    ),
                  ],
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );

            // Generate data after a brief delay
            Future.delayed(const Duration(milliseconds: 300), () {
              _generateFakeDataForOnboarding();
            });
          }

          if (stepIndex == 11) {
            setState(() {
              _onboardingStep = stepIndex;
            });
            _trendsKey.currentState?.setOnboardingStep(stepIndex);
            _trendsKey.currentState?.scrollToTop();
          }

          // Steps 12-13: NO scrolling, just spotlight immediately
          if (stepIndex >= 12 && stepIndex <= 13) {
            setState(() {
              _onboardingStep = stepIndex;
            });
            _trendsKey.currentState?.setOnboardingStep(stepIndex);
          }

          // Step 14: Scroll to Current Streak, then spotlight
          if (stepIndex == 14) {
            _trendsKey.currentState?.scrollToWidget(_tutorialTrendsStreakKey);

            // Delay showing spotlight until scroll completes
            Future.delayed(const Duration(milliseconds: 1100), () {
              if (mounted) {
                setState(() {
                  _onboardingStep = stepIndex;
                });
                _trendsKey.currentState?.setOnboardingStep(stepIndex);
              }
            });

            return; // Exit early
          }

          // Step 15: Average Mood - NO scroll (same Y as streak), just spotlight with delay
          if (stepIndex == 15) {
            // Small delay for smooth transition, but no scroll
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                setState(() {
                  _onboardingStep = stepIndex;
                });
                _trendsKey.currentState?.setOnboardingStep(stepIndex);
              }
            });

            return; // Exit early
          }

          // Step 16: Scroll to Peak Time, then spotlight
          if (stepIndex == 16) {
            // Peak Time is in the second row, so we need to scroll
            _trendsKey.currentState?.scrollToWidget(_tutorialTrendsPeakTimeKey);

            // Delay showing spotlight until scroll completes
            Future.delayed(const Duration(milliseconds: 1100), () {
              if (mounted) {
                setState(() {
                  _onboardingStep = stepIndex;
                });
                _trendsKey.currentState?.setOnboardingStep(stepIndex);
              }
            });

            return; // Exit early
          }

          // Step 17: Consistency - NO scroll (same Y as peak time), just spotlight with delay
          if (stepIndex == 17) {
            // Small delay for smooth transition, but no scroll
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                setState(() {
                  _onboardingStep = stepIndex;
                });
                _trendsKey.currentState?.setOnboardingStep(stepIndex);
              }
            });

            return; // Exit early
          }

          // Step 18: Scroll to Best Day, then spotlight
          if (stepIndex == 18) {
            // Don't update state yet - this prevents spotlight from building
            _trendsKey.currentState?.scrollToWidget(_tutorialTrendsBestDayKey);

            // Delay showing spotlight until scroll completes
            Future.delayed(const Duration(milliseconds: 1100), () {
              if (mounted) {
                setState(() {
                  _onboardingStep = stepIndex;
                });
                _trendsKey.currentState?.setOnboardingStep(stepIndex);
              }
            });

            return; // Exit early
          }

          // Step 19: Toughest Day - NO scroll (same Y as best day), just spotlight with delay
          if (stepIndex == 19) {
            // Small delay for smooth transition, but no scroll
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                setState(() {
                  _onboardingStep = stepIndex;
                });
                _trendsKey.currentState?.setOnboardingStep(stepIndex);
              }
            });

            return; // Exit early
          }

          // Steps 20-22: Update state immediately for these
          if (stepIndex >= 20 && stepIndex <= 22) {
            setState(() {
              _onboardingStep = stepIndex;
            });
          }

          // Step 20: Scroll only, NO spotlight, user taps to continue
          if (stepIndex == 20) {
            _trendsKey.currentState?.scrollToWidget(_tutorialTrendsMoodChartKey);
          }

          // Step 21: Scroll only, NO spotlight, user taps to continue
          if (stepIndex == 21) {
            _trendsKey.currentState?.scrollToWidget(_tutorialTrendsDistributionKey);
          }

          // Step 22: Scroll only, NO spotlight, user taps to continue
          if (stepIndex == 22) {
            _trendsKey.currentState?.scrollToWidget(_tutorialTrendsActivityKey);
          }

          // Step 23: Open drawer (hamburger spotlight)
          if (stepIndex == 23) {
            setState(() => _onboardingStep = stepIndex);
            _trendsKey.currentState?.endOnboarding();
            return;
          }

          // Step 24: Settings navigation
          if (stepIndex == 24) {
            setState(() => _onboardingStep = stepIndex);
            return;
          }

          // Step 25: Theme Modes (SCROLL + spotlight)
          if (stepIndex == 25) {
            _settingsKey.currentState?.scrollToWidget(_settingsThemeModesKey);

            Future.delayed(const Duration(milliseconds: 1100), () {
              if (mounted) {
                setState(() => _onboardingStep = stepIndex);
                _settingsKey.currentState?.setOnboardingStep(stepIndex);
              }
            });
            return;
          }

          // Step 26: Color Themes (NO scroll, spotlight with delay)
          if (stepIndex == 26) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                setState(() => _onboardingStep = stepIndex);
                _settingsKey.currentState?.setOnboardingStep(stepIndex);
              }
            });
            return;
          }

          // Step 27: Privacy (SCROLL + spotlight)
          if (stepIndex == 27) {
            _settingsKey.currentState?.scrollToWidget(_settingsPrivacyKey);

            Future.delayed(const Duration(milliseconds: 1100), () {
              if (mounted) {
                setState(() => _onboardingStep = stepIndex);
                _settingsKey.currentState?.setOnboardingStep(stepIndex);
              }
            });
            return;
          }

          // Step 28: About (NO scroll, spotlight with delay)
          if (stepIndex == 28) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                setState(() => _onboardingStep = stepIndex);
                _settingsKey.currentState?.setOnboardingStep(stepIndex);
              }
            });
            return;
          }

          // Step 29: Back button & open drawer
          if (stepIndex == 29) {
            setState(() => _onboardingStep = stepIndex);
            _settingsKey.currentState?.endOnboarding();
            return;
          }

          // Step 30: Help navigation
          if (stepIndex == 30) {
            setState(() => _onboardingStep = stepIndex);
            return;
          }

          // Step 31: Help content scroll (no spotlight)
          if (stepIndex == 31) {
            setState(() => _onboardingStep = stepIndex);
            _helpKey.currentState?.scrollToWidget(_helpContentKey);

            // Just scroll through help content, no spotlight
            Future.delayed(const Duration(milliseconds: 1000), () {
              if (mounted) {
                // Content has scrolled, ready for next step
              }
            });
            return;
          }

          // Step 32: Done!
          if (stepIndex == 32) {
            setState(() => _onboardingStep = stepIndex);
            _helpKey.currentState?.endOnboarding();
            return;
          }
        },
        onComplete: () async {
          setState(() => _isOnboardingActive = false);
          _moodLogKey.currentState?.endOnboarding();
          _calendarKey.currentState?.endOnboarding();
          _trendsKey.currentState?.endOnboarding();
          _settingsKey.currentState?.endOnboarding();
          _helpKey.currentState?.endOnboarding();
          _clearFakeDataAfterOnboarding();
          await widget.onboardingService.completeTutorial();
          widget.analyticsService.trackEvent('tutorial_completed');
        },
        onSkip: () async {
          setState(() => _isOnboardingActive = false);
          _moodLogKey.currentState?.endOnboarding();
          _calendarKey.currentState?.endOnboarding();
          _trendsKey.currentState?.endOnboarding();
          _settingsKey.currentState?.endOnboarding();
          _helpKey.currentState?.endOnboarding();
          _clearFakeDataAfterOnboarding();
          await widget.onboardingService.completeTutorial();
          widget.analyticsService.trackEvent('tutorial_skipped');
        },
      );
    });
  }

  void _generateFakeDataForOnboarding() {
    if (_hasGeneratedFakeData) return;

    AppLogger.info('Generating fake mood data for onboarding (Trends only)', tag: 'Onboarding');

    final now = DateTime.now();
    final random = Random();
    _fakeDataEntryIds.clear();

    // Generate 60 days of data to ensure period comparison works
    for (int i = 0; i < 60; i++) {
      final date = now.subtract(Duration(days: i));
      final entriesCount = random.nextInt(3) + 1;

      for (int j = 0; j < entriesCount; j++) {
        final rating = random.nextInt(10) + 1;
        final messages = [
          'Feeling great today!',
          'Had a productive morning',
          'Relaxing evening',
          'Good workout session',
          'Quality time with family',
          'Accomplished my goals',
          'Feeling a bit tired',
          'Need more rest',
          'Stressed about work',
          'Excited for tomorrow',
        ];

        final message = random.nextBool() ? messages[random.nextInt(messages.length)] : '';

        // Create the timestamp first so we can derive the ID
        final entryTimestamp = date.subtract(Duration(hours: random.nextInt(12), minutes: random.nextInt(60)));
        final entryId = entryTimestamp.millisecondsSinceEpoch.toString();

        // Track the ID
        _fakeDataEntryIds.add(entryId);

        // Add as TEST data (won't show in Mood Diary)
        _moodService.addTestEntry(
          message,
          rating,
          timestamp: entryTimestamp,
        );
      }
    }

    _hasGeneratedFakeData = true;
    AppLogger.success('Fake data generated for Trends: ${_fakeDataEntryIds.length} test entries', tag: 'Onboarding');
  }

  void _clearFakeDataAfterOnboarding() {
    if (!_hasGeneratedFakeData) return;

    AppLogger.info('Clearing fake onboarding data', tag: 'Onboarding');

    final count = _fakeDataEntryIds.length;

    // Use the new clearTestData method
    _moodService.clearTestData();

    _fakeDataEntryIds.clear();
    _hasGeneratedFakeData = false;
    AppLogger.success('$count fake entries cleared, real data preserved', tag: 'Onboarding');
  }

  void _expandMoodSlider() {
    AppLogger.info('Expanding mood slider for onboarding', tag: 'MainScreen');

    final state = _moodLogKey.currentState;
    if (state != null) {
      state.expandSliderForOnboarding();
      AppLogger.success('Mood slider expanded', tag: 'MainScreen');
    } else {
      AppLogger.error('Could not access MoodLogScreen state', tag: 'MainScreen');
    }
  }

  void _navigateToDate(int tabIndex, DateTime? date) {
    AppLogger.info('Navigation requested to tab $tabIndex with date: ${date?.toString() ?? "none"}', tag: 'MainScreen');

    setState(() {
      _targetDate = date;
      _currentIndex = tabIndex;
    });

    widget.analyticsService.trackScreenView(_getTabName(tabIndex));
    AppLogger.success('Navigated to ${_getTabName(tabIndex)} with date: ${date?.toString() ?? "none"}', tag: 'MainScreen');
  }

  @override
  void dispose() {
    AppLogger.lifecycle('MainScreen disposed', tag: 'MainScreen');
    _drawerController.removeListener(_onDrawerStateChanged);
    super.dispose();
  }

  void _onDrawerStateChanged() {
    // Progress onboarding when drawer opens during step 23 or 29
    if (_isOnboardingActive && _drawerController.isOpen) {
      if (_onboardingStep == 23) {
        AppLogger.info('Drawer opened during step 23, progressing to step 24', tag: 'Onboarding');
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            OnboardingController.nextStep();
          }
        });
      } else if (_onboardingStep == 29) {
        AppLogger.info('Drawer opened during step 29, progressing to step 30', tag: 'Onboarding');
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            OnboardingController.nextStep();
          }
        });
      }
    }
  }

  String _getTabName(int index) {
    switch (index) {
      case 0:
        return 'Calendar';
      case 1:
        return 'Mood Log';
      case 2:
        return 'Trends';
      default:
        return 'Unknown';
    }
  }

  void _onNavigationTap(int index) {
    if (_isOnboardingActive) {
      if (_onboardingStep == 8 && index == 0) {
        AppLogger.info('Calendar navigation allowed during onboarding step 8', tag: 'MainScreen');

        setState(() {
          _targetDate = null;
          _currentIndex = index;
        });

        widget.analyticsService.trackScreenView(_getTabName(index));

        Future.delayed(const Duration(milliseconds: 300), () {
          _calendarKey.currentState?.startOnboarding();
          OnboardingController.nextStep();
        });

        return;
      }

      if (_onboardingStep == 10 && index == 2) {
        AppLogger.info('Trends navigation allowed during onboarding step 10', tag: 'MainScreen');

        setState(() {
          _targetDate = null;
          _currentIndex = index;
        });

        widget.analyticsService.trackScreenView(_getTabName(index));

        _trendsKey.currentState?.startOnboarding();
        OnboardingController.nextStep();

        return;
      }

      AppLogger.warning('Navigation blocked during onboarding - step: $_onboardingStep, index: $index', tag: 'MainScreen');
      return;
    }

    AppLogger.info('Navigation tab tapped: ${_getTabName(index)}', tag: 'MainScreen');

    setState(() {
      _targetDate = null;
      _currentIndex = index;
    });

    widget.analyticsService.trackScreenView(_getTabName(index));
    AppLogger.success('Navigated to ${_getTabName(index)}', tag: 'MainScreen');
  }

  void _navigateToSettings() {
    AppLogger.info('Navigating to settings', tag: 'Navigation');

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          key: _settingsKey,
          themeService: widget.themeService,
          analyticsService: widget.analyticsService,
          drawerController: _drawerController,
          onboardingService: widget.onboardingService,
          moodService: _moodService,
          themeModesKey: _settingsThemeModesKey,
          colorThemesKey: _settingsColorThemesKey,
          privacyKey: _settingsPrivacyKey,
          aboutKey: _settingsAboutKey,
        ),
      ),
    ).then((_) {
      // Handle return from settings during onboarding
      if (_isOnboardingActive && _onboardingStep == 29) {
        // User returned from settings, ready for Help screen navigation
        AppLogger.info('Returned from Settings during step 29', tag: 'Onboarding');
      }
    });

    _drawerController.close();

    // Progress onboarding when navigating to settings during step 24
    if (_isOnboardingActive && _onboardingStep == 24) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _settingsKey.currentState?.startOnboarding();
          _settingsKey.currentState?.scrollToTop();
          OnboardingController.nextStep();
        }
      });
    }
  }

  void _navigateToHelp() {
    AppLogger.info('Navigating to help', tag: 'Navigation');

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => HelpScreen(
          key: _helpKey,
          drawerController: _drawerController,
          contentKey: _helpContentKey,
        ),
      ),
    ).then((_) {
      // Handle return from help
      if (_isOnboardingActive) {
        AppLogger.info('Returned from Help during onboarding', tag: 'Onboarding');
      }
    });

    _drawerController.close();

    // Progress onboarding when navigating to help during step 30
    if (_isOnboardingActive && _onboardingStep == 30) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _helpKey.currentState?.startOnboarding();
          OnboardingController.nextStep();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    PerformanceTestHelper.recordBuild('MainScreen');

    final screens = [
      _calendarScreen,
      MoodLogScreen(
        key: _moodLogKey,
        moodService: _moodService,
        initialDate: _targetDate,
        drawerController: _drawerController,
        themeService: widget.themeService,
        textFieldKey: _tutorialTextFieldKey,
        sliderKey: _tutorialSliderKey,
        sendButtonKey: _tutorialSendButtonKey,
        calendarExpandKey: _tutorialCalendarExpandKey,
        hamburgerKey: _hamburgerMenuKey,
      ),
      _trendsScreen,
    ];

    return DrawerWrapper(
      controller: _drawerController,
      onSettingsTap: _navigateToSettings,
      onHelpTap: _navigateToHelp,
      onCalendarTap: () => _onNavigationTap(0),
      onDiaryTap: () => _onNavigationTap(1),
      onTrendsTap: () => _onNavigationTap(2),
      hamburgerKey: _hamburgerMenuKey,
      settingsKey: _drawerSettingsKey,
      helpKey: _drawerHelpKey,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
        bottomNavigationBar: ModernNavBar(
          currentIndex: _currentIndex,
          onTap: _onNavigationTap,
          calendarKey: _calendarTabKey,
          diaryKey: _diaryTabKey,
          trendsKey: _trendsTabKey,
          isOnboardingActive: _isOnboardingActive,
          onboardingStep: _onboardingStep,
        ),
      ),
    );
  }
}