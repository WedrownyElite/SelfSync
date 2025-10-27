import 'package:flutter/material.dart';
import 'utils/app_logger.dart';
import 'utils/performance_test_helper.dart';
import 'screens/calendar_screen.dart';
import 'screens/mood_log_screen.dart';
import 'screens/trends_screen.dart';
import 'screens/settings_screen.dart';
import 'services/mood_service.dart';
import 'services/theme_service.dart';
import 'widgets/modern_nav_bar.dart';
import 'widgets/side_drawer.dart';

void main() {
  // Log app startup
  AppLogger.separator(label: 'SELF SYNC APP STARTUP');
  AppLogger.lifecycle('App starting...', tag: 'Main');

  runApp(const SelfSyncApp());
  
  AppLogger.lifecycle('App launched successfully', tag: 'Main');
  AppLogger.separator();
}

class SelfSyncApp extends StatefulWidget {
  const SelfSyncApp({super.key});

  @override
  State<SelfSyncApp> createState() => _SelfSyncAppState();
}

class _SelfSyncAppState extends State<SelfSyncApp> {
  late final ThemeService _themeService;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService();
    _themeService.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {
      // Rebuild app with new theme
    });
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.lifecycle('Building SelfSyncApp widget', tag: 'SelfSyncApp');

    return MaterialApp(
      title: 'Self Sync',
      debugShowCheckedModeBanner: false,
      theme: _themeService.getLightTheme(),
      darkTheme: _themeService.getDarkTheme(),
      themeMode: _themeService.themeMode,
      home: MainScreen(themeService: _themeService),
    );
  }
}

class MainScreen extends StatefulWidget {
  final ThemeService themeService;

  const MainScreen({
    super.key,
    required this.themeService,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 1;
  late final MoodService _moodService;
  late final SideDrawerController _drawerController;
  DateTime? _targetDate;

  // ⚡ OPTIMIZATION: Cache CalendarScreen and TrendsScreen
  // MoodLogScreen needs to rebuild when _targetDate changes, so we don't cache it
  late final Widget _calendarScreen;
  late final Widget _trendsScreen;

  @override
  void initState() {
    super.initState();

    AppLogger.lifecycle('MainScreen initializing', tag: 'MainScreen');

    // Initialize services
    try {
      _moodService = MoodService();
      AppLogger.success('MoodService initialized', tag: 'MainScreen');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to initialize MoodService',
          tag: 'MainScreen', error: e, stackTrace: stackTrace);
    }

    try {
      _drawerController = SideDrawerController();
      AppLogger.success('SideDrawerController initialized', tag: 'MainScreen');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to initialize SideDrawerController',
          tag: 'MainScreen', error: e, stackTrace: stackTrace);
    }

    // ⚡ OPTIMIZATION: Initialize screens that don't need to rebuild
    _calendarScreen = CalendarScreen(
      moodService: _moodService,
      onDateSelected: _onDateSelected,
      drawerController: _drawerController,
      themeService: widget.themeService,
    );

    _trendsScreen = TrendsScreen(
      moodService: _moodService,
      onNavigateToTab: _onNavigateToTab,
      drawerController: _drawerController,
      themeService: widget.themeService,
    );

    AppLogger.prettyPrint({
      'Initial tab index': _currentIndex.toString(),
      'Tab name': _getTabName(_currentIndex),
      'Target date': _targetDate?.toString() ?? 'null',
    });
  }

  @override
  void dispose() {
    AppLogger.lifecycle('MainScreen disposing', tag: 'MainScreen');
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
    AppLogger.info('Tab tapped: ${_getTabName(index)}', tag: 'Navigation');

    setState(() {
      _currentIndex = index;
      if (index != 0) {
        _targetDate = null;
      }
    });

    AppLogger.success('Navigation completed to ${_getTabName(index)}',
        tag: 'Navigation');
  }

  void _onDateSelected(DateTime date) {
    AppLogger.info('Date selected: $date', tag: 'Calendar');

    setState(() {
      _targetDate = date;
      _currentIndex = 1;
    });

    AppLogger.success('Switched to Mood Log with target date: $date',
        tag: 'Calendar');
  }

  /// Handle navigation from Trends screen to Mood Log with specific date
  void _onNavigateToTab(int tabIndex, DateTime? date) {
    AppLogger.info(
      'Navigation requested to tab $tabIndex with date: ${date?.toString() ?? "none"}',
      tag: 'MainScreen',
    );

    setState(() {
      _targetDate = date;
      _currentIndex = tabIndex;
    });

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
          drawerController: _drawerController,
        ),
      ),
    );

    _drawerController.close();
  }

  @override
  Widget build(BuildContext context) {
    // Track builds for performance testing
    PerformanceTestHelper.recordBuild('MainScreen');

    // Build the screen list dynamically to handle _targetDate changes
    final screens = [
      _calendarScreen,
      MoodLogScreen(
        key: ValueKey(_targetDate), // Force rebuild when date changes
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
        // ⚡ OPTIMIZATION: Use IndexedStack instead of switching widgets
        // This keeps Calendar and Trends screens cached
        // MoodLogScreen rebuilds when _targetDate changes
        body: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
        bottomNavigationBar: ModernNavBar(
          currentIndex: _currentIndex,
          onTap: _onNavigationTap,
        ),
      ),
    );
  }
}