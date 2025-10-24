import 'package:flutter/material.dart';
import 'utils/app_logger.dart';
import 'screens/calendar_screen.dart';
import 'screens/mood_log_screen.dart';
import 'screens/trends_screen.dart';
import 'services/mood_service.dart';
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

class SelfSyncApp extends StatelessWidget {
  const SelfSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    AppLogger.lifecycle('Building SelfSyncApp widget', tag: 'SelfSyncApp');

    return MaterialApp(
      title: 'Self Sync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          secondary: const Color(0xFFFF6B9D),
          surface: const Color(0xFF1A1A2E),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 1;
  late final MoodService _moodService;
  late final SideDrawerController _drawerController;
  DateTime? _targetDate;

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
          tag: 'MainScreen',
          error: e,
          stackTrace: stackTrace
      );
    }

    try {
      _drawerController = SideDrawerController();
      AppLogger.success('SideDrawerController initialized', tag: 'MainScreen');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to initialize SideDrawerController',
          tag: 'MainScreen',
          error: e,
          stackTrace: stackTrace
      );
    }

    AppLogger.prettyPrint({
      'Initial tab index': _currentIndex.toString(),
      'Tab name': _getTabName(_currentIndex),
      'Target date': _targetDate?.toString() ?? 'null',
    }, title: 'MainScreen State', tag: 'MainScreen');
  }

  @override
  void dispose() {
    AppLogger.lifecycle('MainScreen disposing', tag: 'MainScreen');
    _drawerController.dispose();
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

  void _onNavTap(int index) {
    final fromTab = _getTabName(_currentIndex);
    final toTab = _getTabName(index);

    AppLogger.navigation(fromTab, toTab);

    setState(() {
      _currentIndex = index;
      if (index != 1) {
        if (_targetDate != null) {
          AppLogger.debug('Clearing target date (navigating away from Mood Log)',
              tag: 'MainScreen'
          );
        }
        _targetDate = null;
      }
    });

    AppLogger.debug('Current tab: $toTab (index: $index)', tag: 'MainScreen');
  }

  void _handleNavigateToTab(int tabIndex, DateTime? date) {
    final fromTab = _getTabName(_currentIndex);
    final toTab = _getTabName(tabIndex);

    if (date != null) {
      final dateStr = date.toString().split(' ')[0];
      AppLogger.navigation(fromTab, '$toTab ($dateStr)');
      AppLogger.data('Date-specific navigation',
          details: 'Target date: $dateStr',
          tag: 'MainScreen'
      );
    } else {
      AppLogger.navigation(fromTab, toTab);
    }

    setState(() {
      _currentIndex = tabIndex;
      _targetDate = date;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Only log occasionally to avoid spam (every 10th build or when target date changes)
    // This is a good practice since build() can be called frequently

    return DrawerWrapper(
      controller: _drawerController,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            CalendarScreen(
              moodService: _moodService,
              drawerController: _drawerController,
            ),
            MoodLogScreen(
              moodService: _moodService,
              initialDate: _targetDate,
              drawerController: _drawerController,
              key: _targetDate != null ? ValueKey(_targetDate) : null,
            ),
            TrendsScreen(
              moodService: _moodService,
              onNavigateToTab: _handleNavigateToTab,
              drawerController: _drawerController,
            ),
          ],
        ),
        bottomNavigationBar: ModernNavBar(
          currentIndex: _currentIndex,
          onTap: _onNavTap,
        ),
      ),
    );
  }
}