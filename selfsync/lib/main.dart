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
import 'widgets/tutorial_overlay.dart';

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

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('MainScreen initialized', tag: 'MainScreen');

    _moodService = MoodService();
    _drawerController = SideDrawerController();

    _calendarScreen = CalendarScreen(
      moodService: _moodService,
      onDateSelected: (date) => _navigateToDate(1, date),
      drawerController: _drawerController,
      themeService: widget.themeService,
    );

    _trendsScreen = TrendsScreen(
      moodService: _moodService,
      drawerController: _drawerController,
      themeService: widget.themeService,
    );

    widget.analyticsService.trackScreenView(_getTabName(_currentIndex));

    // Show tutorial after first frame if user hasn't completed it
    if (widget.onboardingService.shouldShowTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Add a small delay to ensure everything is rendered
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _showTutorial();
          }
        });
      });
    }
  }

  void _showTutorial() {
    widget.analyticsService.trackEvent('tutorial_started');

    final tutorialSteps = [
      TutorialStep(
        title: 'Welcome to Self Sync!',
        description: 'Let\'s take a quick tour to help you get started with tracking your mood.',
        icon: Icons.waving_hand_rounded,
      ),
      TutorialStep(
        title: 'Add Mood Entries',
        description: 'Tap here to log how you\'re feeling. You can rate your mood from 1-10 and add notes about what affected it.',
        icon: Icons.edit_note_rounded,
        targetKey: _diaryTabKey,
      ),
      TutorialStep(
        title: 'View Your Calendar',
        description: 'See your mood history at a glance. Each day shows your average mood with color coding.',
        icon: Icons.calendar_month_rounded,
        targetKey: _calendarTabKey,
      ),
      TutorialStep(
        title: 'Analyze Trends',
        description: 'Discover patterns in your emotional well-being with charts and insights over different time periods.',
        icon: Icons.insights_rounded,
        targetKey: _trendsTabKey,
      ),
      TutorialStep(
        title: 'You\'re All Set!',
        description: 'Start tracking your mood consistently to unlock meaningful insights about your emotional patterns. Tap the menu icon in the top-left to access settings anytime.',
        icon: Icons.check_circle_rounded,
      ),
    ];

    TutorialController.show(
      context,
      steps: tutorialSteps,
      onComplete: () async {
        await widget.onboardingService.completeTutorial();
        widget.analyticsService.trackEvent('tutorial_completed');
      },
      onSkip: () async {
        await widget.onboardingService.completeTutorial();
        widget.analyticsService.trackEvent('tutorial_skipped');
      },
    );
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
    AppLogger.info(
      'Navigation tab tapped: ${_getTabName(index)}',
      tag: 'MainScreen',
    );

    setState(() {
      _targetDate = null;
      _currentIndex = index;
    });

    widget.analyticsService.trackScreenView(_getTabName(index));

    AppLogger.success(
      'Navigated to ${_getTabName(index)}',
      tag: 'MainScreen',
    );
  }

  void _navigateToDate(int tabIndex, DateTime? date) {
    AppLogger.info(
      'Navigation requested to tab $tabIndex with date: ${date?.toString() ?? "none"}',
      tag: 'MainScreen',
    );

    setState(() {
      _targetDate = date;
      _currentIndex = tabIndex;
    });

    widget.analyticsService.trackScreenView(_getTabName(tabIndex));

    AppLogger.success(
      'Navigated to ${_getTabName(tabIndex)} with date: ${date?.toString() ?? "none"}',
      tag: 'MainScreen',
    );
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
        key: ValueKey(_targetDate),
        moodService: _moodService,
        initialDate: _targetDate,
        drawerController: _drawerController,
        themeService: widget.themeService,
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
        ),
      ),
    );
  }
}