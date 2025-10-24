import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Professional logging utility for Self Sync app
/// 
/// Uses dart:developer log() instead of print() to avoid lint warnings
/// and provide better debugging capabilities in development.
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

  // Color codes for terminal output (works in most IDEs)
  static const String _gray = '\x1B[90m';
  static const String _blue = '\x1B[34m';
  static const String _yellow = '\x1B[33m';
  static const String _red = '\x1B[31m';
  static const String _green = '\x1B[32m';
  static const String _cyan = '\x1B[36m';
  static const String _magenta = '\x1B[35m';

  /// Log a debug message (lowest priority)
  /// Used for detailed debugging information
  static void debug(String message, {String? tag}) {
    _log(levelDebug, '🔍', _gray, message, tag: tag);
  }

  /// Log an info message (general information)
  /// Used for general application flow information
  static void info(String message, {String? tag}) {
    _log(levelInfo, 'ℹ️', _blue, message, tag: tag);
  }

  /// Log a warning message (something unusual but not breaking)
  /// Used for potentially problematic situations
  static void warning(String message, {String? tag}) {
    _log(levelWarning, '⚠️', _yellow, message, tag: tag);
  }

  /// Log an error message (something went wrong)
  /// Used for errors and exceptions
  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(levelError, '❌', _red, message, tag: tag);
    if (error != null) {
      developer.log(
        'Error details: $error',
        name: tag ?? 'AppLogger',
        level: 1000,
      );
    }
    if (stackTrace != null) {
      developer.log(
        'Stack trace:\n$stackTrace',
        name: tag ?? 'AppLogger',
        level: 1000,
      );
    }
  }

  /// Log a success message (operation completed successfully)
  /// Used for successful operations
  static void success(String message, {String? tag}) {
    _log(levelInfo, '✅', _green, message, tag: tag);
  }

  /// Log navigation events
  static void navigation(String from, String to) {
    _log(levelDebug, '🧭', _cyan, 'Navigation: $from → $to', tag: 'Navigation');
  }

  /// Log data operations (CRUD)
  static void data(String operation, {String? details, String? tag}) {
    final msg = details != null ? '$operation: $details' : operation;
    _log(levelDebug, '💾', _magenta, msg, tag: tag ?? 'Data');
  }

  /// Log lifecycle events (widget/app lifecycle)
  static void lifecycle(String message, {String? tag}) {
    _log(levelDebug, '♻️', _cyan, message, tag: tag ?? 'Lifecycle');
  }

  /// Create a visual separator in logs
  static void separator({String? label}) {
    if (!isEnabled || logLevel > levelDebug) return;

    final line = '═' * 60;
    if (label != null) {
      developer.log('$line\n  $label\n$line', name: 'AppLogger');
    } else {
      developer.log(line, name: 'AppLogger');
    }
  }

  // Core logging function
  static void _log(int level, String emoji, String color, String message, {String? tag}) {
    if (!isEnabled || level < logLevel) return;

    final timestamp = DateTime.now();

    final tagStr = tag != null ? '[$tag] ' : '';
    final logMessage = '$emoji $tagStr$message';

    // Use dart:developer log() instead of print()
    // This appears in the debugger but doesn't trigger avoid_print lint
    developer.log(
      logMessage,
      name: tag ?? 'AppLogger',
      time: timestamp,
      level: level,
    );
  }

  /// Pretty print a map/object for debugging
  static void prettyPrint(Map<String, dynamic> data, {String? title, String? tag}) {
    if (!isEnabled || logLevel > levelDebug) return;

    separator(label: title);
    data.forEach((key, value) {
      developer.log('  $key: $value', name: tag ?? 'AppLogger');
    });
    separator();
  }

  /// Log a list of items
  static void list(String title, List<dynamic> items, {String? tag}) {
    if (!isEnabled || logLevel > levelDebug) return;

    separator(label: title);
    for (var i = 0; i < items.length; i++) {
      developer.log('  [$i] ${items[i]}', name: tag ?? 'AppLogger');
    }
    developer.log('  Total: ${items.length} items', name: tag ?? 'AppLogger');
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