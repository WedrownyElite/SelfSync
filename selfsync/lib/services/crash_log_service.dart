import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/app_logger.dart';

class CrashLog {
  final String id;
  final DateTime timestamp;
  final String error;
  final String stackTrace;
  final String? deviceInfo;
  final String? appVersion;
  final String? screenName;
  final Map<String, dynamic>? additionalContext;

  CrashLog({
    required this.id,
    required this.timestamp,
    required this.error,
    required this.stackTrace,
    this.deviceInfo,
    this.appVersion,
    this.screenName,
    this.additionalContext,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'error': error,
    'stackTrace': stackTrace,
    'deviceInfo': deviceInfo,
    'appVersion': appVersion,
    'screenName': screenName,
    'additionalContext': additionalContext,
  };

  String toFormattedString() {
    final buffer = StringBuffer();
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('CRASH REPORT - ${timestamp.toIso8601String()}');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln();
    buffer.writeln('App Version: ${appVersion ?? 'Unknown'}');
    buffer.writeln('Screen: ${screenName ?? 'Unknown'}');
    buffer.writeln();
    buffer.writeln('─── Device Info ───');
    buffer.writeln(deviceInfo ?? 'Unknown');
    buffer.writeln();
    buffer.writeln('─── Error ───');
    buffer.writeln(error);
    buffer.writeln();
    buffer.writeln('─── Stack Trace ───');
    buffer.writeln(stackTrace);
    if (additionalContext != null && additionalContext!.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('─── Additional Context ───');
      additionalContext!.forEach((key, value) {
        buffer.writeln('$key: $value');
      });
    }
    buffer.writeln();
    buffer.writeln('═══════════════════════════════════════');
    return buffer.toString();
  }
}

class CrashLogService {
  static final CrashLogService _instance = CrashLogService._internal();
  factory CrashLogService() => _instance;
  CrashLogService._internal();

  String? _deviceInfo;
  String? _appVersion;
  String? _currentScreen;
  final Map<String, dynamic> _additionalContext = {};

  CrashLog? _pendingCrashLog;

  CrashLog? get pendingCrashLog => _pendingCrashLog;

  Future<void> initialize() async {
    await _collectDeviceInfo();
    await _collectAppInfo();
    AppLogger.info('CrashLogService initialized', tag: 'CrashLogService');
  }

  Future<void> _collectDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final buffer = StringBuffer();

      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        buffer.writeln('Platform: Android ${info.version.release}');
        buffer.writeln('SDK: ${info.version.sdkInt}');
        buffer.writeln('Device: ${info.manufacturer} ${info.model}');
        buffer.writeln('Product: ${info.product}');
        buffer.writeln('Hardware: ${info.hardware}');
        buffer.writeln('Is Physical: ${info.isPhysicalDevice}');
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        buffer.writeln('Platform: iOS ${info.systemVersion}');
        buffer.writeln('Device: ${info.model}');
        buffer.writeln('Name: ${info.name}');
        buffer.writeln('Is Physical: ${info.isPhysicalDevice}');
      }

      _deviceInfo = buffer.toString();
    } catch (e) {
      _deviceInfo = 'Failed to collect device info: $e';
      AppLogger.error('Failed to collect device info: $e', tag: 'CrashLogService');
    }
  }

  Future<void> _collectAppInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = '${info.version} (${info.buildNumber})';
    } catch (e) {
      _appVersion = 'Unknown';
      AppLogger.error('Failed to collect app info: $e', tag: 'CrashLogService');
    }
  }

  void setCurrentScreen(String screenName) {
    _currentScreen = screenName;
  }

  void addContext(String key, dynamic value) {
    _additionalContext[key] = value;
  }

  void clearContext() {
    _additionalContext.clear();
  }

  CrashLog createCrashLog(Object error, StackTrace? stackTrace) {
    final crashLog = CrashLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      error: error.toString(),
      stackTrace: stackTrace?.toString() ?? 'No stack trace available',
      deviceInfo: _deviceInfo,
      appVersion: _appVersion,
      screenName: _currentScreen,
      additionalContext: Map.from(_additionalContext),
    );

    _pendingCrashLog = crashLog;

    // Also save to file for persistence
    _saveCrashLogToFile(crashLog);

    return crashLog;
  }

  Future<void> _saveCrashLogToFile(CrashLog crashLog) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final crashDir = Directory('${directory.path}/crash_logs');
      if (!await crashDir.exists()) {
        await crashDir.create(recursive: true);
      }

      final file = File('${crashDir.path}/crash_${crashLog.id}.txt');
      await file.writeAsString(crashLog.toFormattedString());

      AppLogger.info('Crash log saved to ${file.path}', tag: 'CrashLogService');
    } catch (e) {
      AppLogger.error('Failed to save crash log: $e', tag: 'CrashLogService');
    }
  }

  Future<List<CrashLog>> getPendingCrashLogs() async {
    final logs = <CrashLog>[];

    try {
      final directory = await getApplicationDocumentsDirectory();
      final crashDir = Directory('${directory.path}/crash_logs');

      if (await crashDir.exists()) {
        final files = crashDir.listSync().whereType<File>();
        for (final file in files) {
          if (file.path.endsWith('.txt')) {
            // For simplicity, we just track that logs exist
            // Full parsing would require more complex logic
          }
        }
      }
    } catch (e) {
      AppLogger.error('Failed to get pending crash logs: $e', tag: 'CrashLogService');
    }

    if (_pendingCrashLog != null) {
      logs.add(_pendingCrashLog!);
    }

    return logs;
  }

  Future<void> clearPendingCrashLog() async {
    if (_pendingCrashLog != null) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/crash_logs/crash_${_pendingCrashLog!.id}.txt');
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        AppLogger.error('Failed to delete crash log file: $e', tag: 'CrashLogService');
      }
      _pendingCrashLog = null;
    }
  }

  Future<void> clearAllCrashLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final crashDir = Directory('${directory.path}/crash_logs');
      if (await crashDir.exists()) {
        await crashDir.delete(recursive: true);
      }
      _pendingCrashLog = null;
      AppLogger.info('All crash logs cleared', tag: 'CrashLogService');
    } catch (e) {
      AppLogger.error('Failed to clear crash logs: $e', tag: 'CrashLogService');
    }
  }
}