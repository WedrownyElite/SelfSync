import 'package:flutter/material.dart';
import 'utils/app_logger.dart';
import 'utils/performance_test_helper.dart';
import 'screens/calendar_screen.dart';
import 'screens/mood_log_screen.dart';
import 'screens/trends_screen.dart';
import 'screens/settings_screen.dart';
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

  // Tutorial keys for CalendarScreen
  final GlobalKey _tutorialCalendarViewToggleKey = GlobalKey();

  // Tutorial keys for TrendsScreen  
  final GlobalKey _tutorialTrendsDatePresetsKey = GlobalKey();

  final GlobalKey<CalendarScreenState> _calendarKey = GlobalKey<CalendarScreenState>();
  final GlobalKey<TrendsScreenState> _trendsKey = GlobalKey<TrendsScreenState>();

  bool _hasGeneratedFakeData = false;

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('MainScreen initialized', tag: 'MainScreen');

    _moodService = MoodService();
    _drawerController = SideDrawerController();

    _calendarScreen = CalendarScreen(
      key: _calendarKey,
      moodService: _moodService,
      onDateSelected: (date) => _navigateToDate(1, date),
      drawerController: _drawerController,
      themeService: widget.themeService,
      viewToggleKey: _tutorialCalendarViewToggleKey,
    );

    _trendsScreen = TrendsScreen(
      key: _trendsKey,
      moodService: _moodService,
      drawerController: _drawerController,
      themeService: widget.themeService,
      datePresetsKey: _tutorialTrendsDatePresetsKey,
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
      _onboardingStep = 0; // Initialize to 0
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
          centerCard: true, // Show in center of screen
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
          requiresAction: true, // User must interact to continue
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
          description: 'Here you can see all your mood entries displayed on a calendar. Try tapping the view options button to switch between Grid, Circle, and Condensed layouts!',
          targetKey: _tutorialCalendarViewToggleKey,
          actionHint: 'Tap to continue',
          requiresAction: false,
          showOverlay: false,
        ),
        OnboardingStep(
          title: 'All Set! 🎉',
          description: 'You\'re ready to track your moods! Feel free to explore the Trends tab to see deeper insights into your emotional patterns.',
          actionHint: 'Tap to finish',
          requiresAction: false,
        ),
      ];

      OnboardingController.start(
        context,
        steps: steps,
        onStepChanged: (stepIndex) {
          AppLogger.separator(label: 'STEP CHANGE');
          AppLogger.info('Onboarding step changed to: $stepIndex', tag: 'MainScreen');

          // Track current step - CRITICAL!
          setState(() {
            _onboardingStep = stepIndex;
          });

          AppLogger.debug('_onboardingStep updated to: $_onboardingStep', tag: 'MainScreen');
          AppLogger.debug('_isOnboardingActive: $_isOnboardingActive', tag: 'MainScreen');
          AppLogger.separator();

          _moodLogKey.currentState?.setOnboardingStep(stepIndex);

          if (stepIndex == 2) {
            _expandMoodSlider();
          }

          // End calendar onboarding when moving past calendar steps
          if (stepIndex == 11) {
            _calendarKey.currentState?.endOnboarding();
          }
        },
        onComplete: () async {
          setState(() => _isOnboardingActive = false);
          _moodLogKey.currentState?.endOnboarding();
          _calendarKey.currentState?.endOnboarding();
          _trendsKey.currentState?.endOnboarding();
          _clearFakeDataAfterOnboarding();
          await widget.onboardingService.completeTutorial();
          widget.analyticsService.trackEvent('tutorial_completed');
        },
        onSkip: () async {
          setState(() => _isOnboardingActive = false);
          _moodLogKey.currentState?.endOnboarding();
          _calendarKey.currentState?.endOnboarding();
          _trendsKey.currentState?.endOnboarding();
          _clearFakeDataAfterOnboarding();
          await widget.onboardingService.completeTutorial();
          widget.analyticsService.trackEvent('tutorial_skipped');
        },
      );
    });
  }

  void _expandMoodSlider() {
    AppLogger.info('Expanding mood slider for onboarding', tag: 'MainScreen');

    // Access the MoodLogScreen state and expand the slider
    final state = _moodLogKey.currentState;
    if (state != null) {
      state.expandSliderForOnboarding();
      AppLogger.success('Mood slider expanded', tag: 'MainScreen');
    } else {
      AppLogger.error('Could not access MoodLogScreen state', tag: 'MainScreen');
    }
  }

  void _clearFakeDataAfterOnboarding() {
    if (!_hasGeneratedFakeData) return;

    AppLogger.info('Clearing fake onboarding data', tag: 'Onboarding');
    _moodService.clearAllEntries();
    _hasGeneratedFakeData = false;
    AppLogger.success('Fake data cleared', tag: 'Onboarding');
  }

  @override
  void dispose() {
    AppLogger.lifecycle('MainScreen disposed', tag: 'MainScreen');
    super.dispose();
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
    // During onboarding, only allow Calendar tab (index 0) during step 9
    if (_isOnboardingActive && _onboardingStep == 9 && index == 0) {
      // Allow calendar navigation during step 9
      AppLogger.info('Calendar navigation allowed during onboarding step 9', tag: 'MainScreen');

      setState(() {
        _targetDate = null;
        _currentIndex = index;
      });

      widget.analyticsService.trackScreenView(_getTabName(index));

      // Start calendar onboarding and progress to next step
      _calendarKey.currentState?.startOnboarding();
      OnboardingController.nextStep();

      return;
    }

    if (_isOnboardingActive) {
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

  void _navigateToDate(int tabIndex, DateTime? date) {
    AppLogger.info('Navigation requested to tab $tabIndex with date: ${date?.toString() ?? "none"}', tag: 'MainScreen');

    setState(() {
      _targetDate = date;
      _currentIndex = tabIndex;
    });

    widget.analyticsService.trackScreenView(_getTabName(tabIndex));
    AppLogger.success('Navigated to ${_getTabName(tabIndex)} with date: ${date?.toString() ?? "none"}', tag: 'MainScreen');
  }

  void _navigateToSettings() {
    AppLogger.info('Navigating to settings', tag: 'Navigation');

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          themeService: widget.themeService,
          analyticsService: widget.analyticsService,
          drawerController: _drawerController,
          onboardingService: widget.onboardingService,
        ),
      ),
    );

    _drawerController.close();
  }

  @override
  Widget build(BuildContext context) {
    PerformanceTestHelper.recordBuild('MainScreen');

    final screens = [
      _calendarScreen,
      MoodLogScreen(
        key: _moodLogKey, // Use the state key here
        moodService: _moodService,
        initialDate: _targetDate,
        drawerController: _drawerController,
        themeService: widget.themeService,
        textFieldKey: _tutorialTextFieldKey,
        sliderKey: _tutorialSliderKey,
        sendButtonKey: _tutorialSendButtonKey,
        calendarExpandKey: _tutorialCalendarExpandKey,
      ),
      _trendsScreen,
    ];

    return DrawerWrapper(
      controller: _drawerController,
      onSettingsTap: _navigateToSettings,
      onCalendarTap: () => _onNavigationTap(0),
      onDiaryTap: () => _onNavigationTap(1),
      onTrendsTap: () => _onNavigationTap(2),
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