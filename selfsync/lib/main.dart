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

    // Check if privacy policy needs to be accepted first
    if (!widget.onboardingService.privacyAccepted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPrivacyPolicy();
      });
    }
    // Otherwise check if tutorial should be shown
    else if (widget.onboardingService.shouldShowTutorial) {
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

        // Show tutorial after privacy acceptance
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
        // User declined - you could exit the app here or show a message
        AppLogger.warning('User declined privacy policy', tag: 'MainScreen');
      },
    );
  }

  void _showTutorial() {
    AppLogger.info('Starting interactive tutorial', tag: 'MainScreen');
    widget.analyticsService.trackEvent('tutorial_started');

    // Navigate to mood diary screen for the tutorial
    setState(() {
      _currentIndex = 1;
    });

    final tutorialSteps = [
      InteractiveTutorialStep(
        title: 'Welcome to Your Mood Diary! 👋',
        description: 'This is where you\'ll track your daily moods. Let\'s learn by doing - we\'ll guide you through creating your first mood entry!',
        actionInstruction: 'Tap anywhere to start',
      ),
      InteractiveTutorialStep(
        title: 'Step 1: Tap the Input Field',
        description: 'See the message box at the bottom? Tap it to start logging your mood.',
        targetKey: _diaryTabKey,
        actionInstruction: 'Tap the input field at the bottom of the screen',
      ),
      InteractiveTutorialStep(
        title: 'Step 2: Choose Your Mood',
        description: 'Great! Now use the slider to rate how you\'re feeling from 1 (struggling) to 10 (excellent). Watch the emoji change!',
        actionInstruction: 'Move the mood slider to any rating you like',
      ),
      InteractiveTutorialStep(
        title: 'Step 3: Add a Message (Optional)',
        description: 'Type a short note about why you feel this way. It helps you remember what influenced your mood!',
        actionInstruction: 'Type a message or skip by tapping the send button',
      ),
      InteractiveTutorialStep(
        title: 'Step 4: Send Your Entry',
        description: 'Perfect! Now tap the send button (paper plane icon) to save your mood entry.',
        actionInstruction: 'Tap the send button to log your mood',
      ),
      InteractiveTutorialStep(
        title: 'Edit & Delete Entries',
        description: 'You can manage your entries easily: Long press any entry to edit it, or swipe right to delete it.',
        actionInstruction: 'Try long-pressing or swiping an entry (or tap to continue)',
      ),
      InteractiveTutorialStep(
        title: 'Calendar Filtering',
        description: 'Tap the down arrow at the top to expand the calendar. You can filter entries by date or create a date range.',
        actionInstruction: 'Tap the arrow to expand the calendar',
      ),
      InteractiveTutorialStep(
        title: 'Explore the App!',
        description: 'Great job! Check out the Calendar and Trends tabs below to see your mood patterns over time.',
        actionInstruction: 'Tap anywhere to finish the tutorial',
      ),
    ];

    InteractiveTutorialController.show(
      context,
      steps: tutorialSteps,
      onComplete: () async {
        await widget.onboardingService.completeTutorial();
        widget.analyticsService.trackEvent('tutorial_completed');
        AppLogger.success('Tutorial completed', tag: 'MainScreen');
      },
      onSkip: () async {
        await widget.onboardingService.completeTutorial();
        widget.analyticsService.trackEvent('tutorial_skipped');
        AppLogger.info('Tutorial skipped', tag: 'MainScreen');
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