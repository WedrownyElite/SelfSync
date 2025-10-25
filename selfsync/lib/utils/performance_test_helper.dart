// lib/utils/performance_test_helper.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';

/// Performance testing utility for SelfSync app
/// 
/// Usage: Run app in Profile mode and check console output
/// flutter run --profile
class PerformanceTestHelper {
  // Singleton
  static final PerformanceTestHelper _instance = PerformanceTestHelper._internal();
  factory PerformanceTestHelper() => _instance;
  PerformanceTestHelper._internal();

  // Only enable in profile/debug mode
  static bool get isEnabled => !kReleaseMode;

  // Performance counters
  static int mainScreenBuilds = 0;
  static int calendarScreenBuilds = 0;
  static int moodLogScreenBuilds = 0;
  static int trendsScreenBuilds = 0;

  // Timing measurements
  static final Map<String, List<int>> _timings = {};
  static final Map<String, Stopwatch> _activeStopwatches = {};

  /// Start timing an operation
  static void startTimer(String operation) {
    if (!isEnabled) return;
    _activeStopwatches[operation] = Stopwatch()..start();
  }

  /// Stop timing and record result
  static void stopTimer(String operation) {
    if (!isEnabled) return;
    final stopwatch = _activeStopwatches[operation];
    if (stopwatch == null) return;

    stopwatch.stop();
    final ms = stopwatch.elapsedMilliseconds;

    _timings.putIfAbsent(operation, () => []);
    _timings[operation]!.add(ms);

    // Log slow operations (>16ms = dropped frame at 60fps)
    if (ms > 16) {
      debugPrint('⚠️ SLOW: $operation took ${ms}ms (>16ms)');
    }

    _activeStopwatches.remove(operation);
  }

  /// Measure a synchronous operation
  static T measure<T>(String operation, T Function() fn) {
    if (!isEnabled) return fn();

    startTimer(operation);
    try {
      return fn();
    } finally {
      stopTimer(operation);
    }
  }

  /// Measure an async operation
  static Future<T> measureAsync<T>(String operation, Future<T> Function() fn) async {
    if (!isEnabled) return await fn();

    startTimer(operation);
    try {
      return await fn();
    } finally {
      stopTimer(operation);
    }
  }

  /// Record a widget rebuild
  static void recordBuild(String widgetName) {
    if (!isEnabled) return;

    switch (widgetName) {
      case 'MainScreen':
        mainScreenBuilds++;
        break;
      case 'CalendarScreen':
        calendarScreenBuilds++;
        break;
      case 'MoodLogScreen':
        moodLogScreenBuilds++;
        break;
      case 'TrendsScreen':
        trendsScreenBuilds++;
        break;
    }
  }

  /// Print comprehensive performance report
  static void printReport() {
    if (!isEnabled) return;

    debugPrint('\n${'═' * 70}');
    debugPrint('📊 PERFORMANCE TEST REPORT');
    // ignore: unnecessary_string_interpolations
    debugPrint('${'═' * 70}');

    // Widget rebuild counts
    debugPrint('\n🔄 WIDGET REBUILD COUNTS:');
    debugPrint('  MainScreen:     $mainScreenBuilds builds');
    debugPrint('  CalendarScreen: $calendarScreenBuilds builds');
    debugPrint('  MoodLogScreen:  $moodLogScreenBuilds builds');
    debugPrint('  TrendsScreen:   $trendsScreenBuilds builds');

    final totalBuilds = mainScreenBuilds + calendarScreenBuilds +
        moodLogScreenBuilds + trendsScreenBuilds;
    debugPrint('  TOTAL:          $totalBuilds builds');

    // Timing statistics
    if (_timings.isNotEmpty) {
      debugPrint('\n⏱️  OPERATION TIMINGS:');

      _timings.forEach((operation, times) {
        if (times.isEmpty) return;

        final avg = times.reduce((a, b) => a + b) / times.length;
        final max = times.reduce((a, b) => a > b ? a : b);
        final min = times.reduce((a, b) => a < b ? a : b);

        final status = avg > 16 ? '❌' : '✅';
        debugPrint('  $status $operation:');
        debugPrint('      Average: ${avg.toStringAsFixed(2)}ms');
        debugPrint('      Min: ${min}ms | Max: ${max}ms');
        debugPrint('      Calls: ${times.length}');
      });
    }

    // Performance warnings
    debugPrint('\n⚡ PERFORMANCE WARNINGS:');
    final warnings = <String>[];

    if (mainScreenBuilds > 20) {
      warnings.add('  ⚠️  MainScreen rebuilding too often ($mainScreenBuilds times)');
    }

    _timings.forEach((operation, times) {
      final avg = times.reduce((a, b) => a + b) / times.length;
      if (avg > 16) {
        warnings.add('  ⚠️  $operation is slow (${avg.toStringAsFixed(2)}ms avg)');
      }
    });

    if (warnings.isEmpty) {
      debugPrint('  ✅ No performance warnings!');
    } else {
      warnings.forEach(debugPrint);
    }

    debugPrint('\n${'═' * 70}');
    debugPrint('');
  }

  /// Reset all counters and timings
  static void reset() {
    mainScreenBuilds = 0;
    calendarScreenBuilds = 0;
    moodLogScreenBuilds = 0;
    trendsScreenBuilds = 0;
    _timings.clear();
    _activeStopwatches.clear();
    debugPrint('🔄 Performance counters reset');
  }

  /// Monitor frame times (use in initState)
  static void monitorFrameTimes(String screenName) {
    if (!isEnabled) return;

    int frameCount = 0;
    int slowFrames = 0;

    SchedulerBinding.instance.addTimingsCallback((timings) {
      for (final timing in timings) {
        frameCount++;
        final frameTimeMs = timing.totalSpan.inMilliseconds;

        if (frameTimeMs > 16) {
          slowFrames++;
          if (frameTimeMs > 32) {
            debugPrint('🐌 $screenName: Dropped frame! ${frameTimeMs}ms');
          }
        }
      }

      // Report every 100 frames
      if (frameCount % 100 == 0) {
        final dropRate = (slowFrames / frameCount * 100).toStringAsFixed(1);
        debugPrint('📊 $screenName: $frameCount frames, $dropRate% slow/dropped');
      }
    });
  }
}

/// Extension for easy widget build tracking
extension PerformanceTrackingWidget on State {
  void trackBuild(String widgetName) {
    PerformanceTestHelper.recordBuild(widgetName);
  }
}

/// Convenience function to wrap expensive operations
T measurePerf<T>(String operation, T Function() fn) {
  return PerformanceTestHelper.measure(operation, fn);
}

Future<T> measurePerfAsync<T>(String operation, Future<T> Function() fn) {
  return PerformanceTestHelper.measureAsync(operation, fn);
}