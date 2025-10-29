import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';

/// Service for basic analytics and error tracking with privacy controls
class AnalyticsService extends ChangeNotifier {
  static const String _analyticsEnabledKey = 'analytics_enabled';
  static const String _crashReportingEnabledKey = 'crash_reporting_enabled';

  bool _analyticsEnabled = true;  // Default enabled
  bool _crashReportingEnabled = true;  // Default enabled

  bool get analyticsEnabled => _analyticsEnabled;
  bool get crashReportingEnabled => _crashReportingEnabled;

  AnalyticsService() {
    _loadPreferences();
  }

  /// Load saved analytics preferences
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    _analyticsEnabled = prefs.getBool(_analyticsEnabledKey) ?? true;
    _crashReportingEnabled = prefs.getBool(_crashReportingEnabledKey) ?? true;

    AppLogger.info('Analytics preferences loaded - Analytics: $_analyticsEnabled, Crash Reporting: $_crashReportingEnabled', tag: 'Analytics');
    notifyListeners();
  }

  /// Set analytics enabled state
  Future<void> setAnalyticsEnabled(bool enabled) async {
    _analyticsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_analyticsEnabledKey, enabled);

    AppLogger.info('Analytics ${enabled ? 'enabled' : 'disabled'}', tag: 'Analytics');
    notifyListeners();
  }

  /// Set crash reporting enabled state
  Future<void> setCrashReportingEnabled(bool enabled) async {
    _crashReportingEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_crashReportingEnabledKey, enabled);

    AppLogger.info('Crash reporting ${enabled ? 'enabled' : 'disabled'}', tag: 'Analytics');
    notifyListeners();
  }

  // ============================================================================
  // Event Tracking
  // ============================================================================

  /// Track app events (only if analytics enabled)
  void trackEvent(String eventName, {Map<String, dynamic>? properties}) {
    if (!_analyticsEnabled) return;

    AppLogger.analytics('Event: $eventName${properties != null ? ' - ${properties.toString()}' : ''}');

    // In a production app, this would send to analytics service
    // For now, we just log locally
  }

  /// Track screen view
  void trackScreenView(String screenName) {
    if (!_analyticsEnabled) return;

    trackEvent('screen_view', properties: {'screen_name': screenName});
  }

  /// Track mood entry creation
  void trackMoodEntry({required int rating, bool hasNote = false}) {
    if (!_analyticsEnabled) return;

    trackEvent('mood_entry_created', properties: {
      'rating': rating,
      'has_note': hasNote,
    });
  }

  /// Track mood entry edit
  void trackMoodEdit() {
    if (!_analyticsEnabled) return;

    trackEvent('mood_entry_edited');
  }

  /// Track mood entry delete
  void trackMoodDelete() {
    if (!_analyticsEnabled) return;

    trackEvent('mood_entry_deleted');
  }

  /// Track trends view
  void trackTrendsView(String timeRange) {
    if (!_analyticsEnabled) return;

    trackEvent('trends_viewed', properties: {'time_range': timeRange});
  }

  /// Track theme change
  void trackThemeChange(String themeMode, String gradient) {
    if (!_analyticsEnabled) return;

    trackEvent('theme_changed', properties: {
      'theme_mode': themeMode,
      'gradient': gradient,
    });
  }

  // ============================================================================
  // Error Tracking
  // ============================================================================

  /// Log error (only if crash reporting enabled)
  void logError(dynamic error, StackTrace? stackTrace, {String? context}) {
    if (!_crashReportingEnabled) return;

    AppLogger.error(
      '${context != null ? '[$context] ' : ''}${error.toString()}',
      stackTrace: stackTrace,
      tag: 'Error',
    );

    // In a production app, this would send to crash reporting service
    // For now, we just log locally
  }

  /// Log caught exception
  void logException(Exception exception, StackTrace? stackTrace, {String? context}) {
    logError(exception, stackTrace, context: context);
  }

  /// Log Flutter framework error
  void logFlutterError(FlutterErrorDetails details) {
    if (!_crashReportingEnabled) return;

    AppLogger.error(
      'Flutter Error: ${details.exceptionAsString()}',
      stackTrace: details.stack,
      tag: 'FlutterError',
    );
  }

  // ============================================================================
  // Performance Tracking
  // ============================================================================

  /// Track app startup time
  void trackAppStartup(Duration duration) {
    if (!_analyticsEnabled) return;

    trackEvent('app_startup', properties: {
      'duration_ms': duration.inMilliseconds,
    });
  }

  /// Track screen load time
  void trackScreenLoad(String screenName, Duration duration) {
    if (!_analyticsEnabled) return;

    trackEvent('screen_load', properties: {
      'screen_name': screenName,
      'duration_ms': duration.inMilliseconds,
    });
  }
}