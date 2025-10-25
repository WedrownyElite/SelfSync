// lib/utils/stress_test.dart
import 'package:flutter/material.dart';

/// Stress testing utilities for SelfSync
/// 
/// Usage: Call from settings screen
class StressTest {
  /// Print test instructions to console
  static void printTestInstructions() {
    debugPrint('\n${'═' * 70}');
    debugPrint('🧪 MANUAL PERFORMANCE TEST INSTRUCTIONS');
    // ignore: unnecessary_string_interpolations
    debugPrint('${'═' * 70}');
    debugPrint('');
    debugPrint('TEST 1: Navigation Performance');
    debugPrint('  1. Tap "Reset Counters" button');
    debugPrint('  2. Tap between Calendar/Mood Log/Trends tabs 10 times');
    debugPrint('  3. Tap "Print Performance Report" button');
    debugPrint('  ✅ Expected: <20 MainScreen builds');
    debugPrint('');
    debugPrint('TEST 2: Scroll Performance');
    debugPrint('  1. Tap "Reset Counters"');
    debugPrint('  2. Go to Mood Log and scroll rapidly for 10 seconds');
    debugPrint('  3. Return to Settings, tap "Print Performance Report"');
    debugPrint('  ✅ Expected: <50 MoodLogScreen builds');
    debugPrint('');
    debugPrint('TEST 3: Calendar Performance');
    debugPrint('  1. Tap "Reset Counters"');
    debugPrint('  2. Open Calendar and switch months 10 times (tap < > arrows)');
    debugPrint('  3. Return to Settings, tap "Print Performance Report"');
    debugPrint('  ✅ Expected: <30 CalendarScreen builds');
    debugPrint('');
    debugPrint('${'═' * 70}\n');
  }

  /// Show simple info dialog
  static void showTestInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📊 Performance Testing'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How to Test:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 12),
              Text('1️⃣ Tap "Reset Counters"'),
              SizedBox(height: 8),
              Text('2️⃣ Use the app normally:'),
              Text('   • Switch between tabs'),
              Text('   • Scroll mood log'),
              Text('   • Change calendar months'),
              SizedBox(height: 8),
              Text('3️⃣ Tap "Print Performance Report"'),
              SizedBox(height: 8),
              Text('4️⃣ Check your Run console for results'),
              SizedBox(height: 12),
              Text(
                'The report shows how many times each screen rebuilt. Lower is better!',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              printTestInstructions();
            },
            child: const Text('Show Detailed Instructions'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }
}