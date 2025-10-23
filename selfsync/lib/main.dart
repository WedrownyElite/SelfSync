import 'package:flutter/material.dart';
import 'screens/calendar_screen.dart';
import 'screens/mood_log_screen.dart';
import 'screens/trends_screen.dart';
import 'services/mood_service.dart';
import 'widgets/modern_nav_bar.dart';

void main() {
  runApp(const VibeCheckApp());
}

class VibeCheckApp extends StatelessWidget {
  const VibeCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VibeCheck',
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
  int _currentIndex = 1; // Start with Diary (center)
  late final MoodService _moodService;
  DateTime? _targetDate; // Date to navigate to in diary

  @override
  void initState() {
    super.initState();
    _moodService = MoodService();
  }

  void _onNavTap(int index) {
    setState(() {
      _currentIndex = index;
      // Clear target date when manually navigating
      if (index != 1) {
        _targetDate = null;
      }
    });
  }

  void _handleNavigateToTab(int tabIndex, DateTime? date) {
    print('🎯 MainScreen: Navigate to tab $tabIndex with date $date');
    setState(() {
      _currentIndex = tabIndex;
      _targetDate = date;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          CalendarScreen(moodService: _moodService),
          MoodLogScreen(
            moodService: _moodService,
            initialDate: _targetDate,
            key: _targetDate != null ? ValueKey(_targetDate) : null,
          ),
          TrendsScreen(
            moodService: _moodService,
            onNavigateToTab: _handleNavigateToTab,
          ),
        ],
      ),
      bottomNavigationBar: ModernNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
    );
  }
}