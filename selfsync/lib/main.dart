import 'package:flutter/material.dart';
import 'screens/calendar_screen.dart';
import 'screens/mood_log_screen.dart';
import 'screens/trends_screen.dart';
import 'services/mood_service.dart';
import 'widgets/modern_nav_bar.dart';
import 'widgets/side_drawer.dart';

void main() {
  runApp(const SelfSyncApp());
}

class SelfSyncApp extends StatelessWidget {
  const SelfSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
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
    _moodService = MoodService();
    _drawerController = SideDrawerController();
  }

  @override
  void dispose() {
    _drawerController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    setState(() {
      _currentIndex = index;
      if (index != 1) {
        _targetDate = null;
      }
    });
  }

  void _handleNavigateToTab(int tabIndex, DateTime? date) {
    setState(() {
      _currentIndex = tabIndex;
      _targetDate = date;
    });
  }

  @override
  Widget build(BuildContext context) {
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