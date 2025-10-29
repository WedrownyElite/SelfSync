// ignore_for_file: avoid_print
import 'package:flutter/foundation.dart';

/// Professional logging utility for Self Sync app
class AppLogger {
  // Singleton pattern
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  // Enable/disable logging globally
  static bool isEnabled = kDebugMode; // Only logs in debug mode by default

  // Log level enum
  static const int levelDebug = 0;
  static const int levelInfo = 1;
  static const int levelWarning = 2;
  static const int levelError = 3;

  // Current log level threshold (logs at this level and above will be shown)
  static int logLevel = levelDebug;

  /// Log a debug message (lowest priority)
  /// Used for detailed debugging information
  static void debug(String message, {String? tag}) {
    _log(levelDebug, '🔍', message, tag: tag);
  }

  /// Log an info message (general information)
  /// Used for general application flow information
  static void info(String message, {String? tag}) {
    _log(levelInfo, 'ℹ️', message, tag: tag);
  }

  /// Log a warning message (something unusual but not breaking)
  /// Used for potentially problematic situations
  static void warning(String message, {String? tag}) {
    _log(levelWarning, '⚠️', message, tag: tag);
  }

  /// Log an error message (something went wrong)
  /// Used for errors and exceptions
  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(levelError, '❌', message, tag: tag);
    if (error != null) {
      print('  └─ Error details: $error');
    }
    if (stackTrace != null) {
      print('  └─ Stack trace:\n$stackTrace');
    }
  }

  /// Log a success message (operation completed successfully)
  /// Used for successful operations
  static void success(String message, {String? tag}) {
    _log(levelInfo, '✅', message, tag: tag);
  }

  /// Log analytics events
  static void analytics(String message, {String? tag}) {
    _log(levelInfo, '📊', message, tag: tag ?? 'Analytics');
  }

  /// Log performance metrics
  static void performance(String message, {String? tag}) {
    _log(levelInfo, '⚡', message, tag: tag ?? 'Performance');
  }

  /// Log navigation events
  static void navigation(String from, String to) {
    _log(levelDebug, '🧭', 'Navigation: $from → $to', tag: 'Navigation');
  }

  /// Log data operations (CRUD)
  static void data(String operation, {String? details, String? tag}) {
    final msg = details != null ? '$operation: $details' : operation;
    _log(levelDebug, '💾', msg, tag: tag ?? 'Data');
  }

  /// Log lifecycle events (widget/app lifecycle)
  static void lifecycle(String message, {String? tag}) {
    _log(levelDebug, '♻️', message, tag: tag ?? 'Lifecycle');
  }

  /// Create a visual separator in logs
  static void separator({String? label}) {
    if (!isEnabled || logLevel > levelDebug) return;

    final line = '═' * 60;
    if (label != null) {
      print('$line\n  $label\n$line');
    } else {
      print(line);
    }
  }

  // Core logging function
  static void _log(int level, String emoji, String message, {String? tag}) {
    if (!isEnabled || level < logLevel) return;

    final tagStr = tag != null ? '[$tag] ' : '';
    final logMessage = '$emoji $tagStr$message';

    // Use print() - it ALWAYS works
    print(logMessage);
  }

  /// Pretty print a map/object for debugging
  static void prettyPrint(Map<String, dynamic> data, {String? title, String? tag}) {
    if (!isEnabled || logLevel > levelDebug) return;

    separator(label: title);
    data.forEach((key, value) {
      print('  $key: $value');
    });
    separator();
  }

  /// Log a list of items
  static void list(String title, List<dynamic> items, {String? tag}) {
    if (!isEnabled || logLevel > levelDebug) return;

    separator(label: title);
    for (var i = 0; i < items.length; i++) {
      print('  [$i] ${items[i]}');
    }
    print('  Total: ${items.length} items');
    separator();
  }
}

/// Convenience extension for easier logging
extension LoggerExtensions on String {
  void logDebug({String? tag}) => AppLogger.debug(this, tag: tag);
  void logInfo({String? tag}) => AppLogger.info(this, tag: tag);
  void logWarning({String? tag}) => AppLogger.warning(this, tag: tag);
  void logError({String? tag, Object? error, StackTrace? stackTrace}) {
    AppLogger.error(this, tag: tag, error: error, stackTrace: stackTrace);
  }
}