import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import '../constants/app_constants.dart';
import '../utils/app_logger.dart';

/// Service for submitting bug reports to the backend
class BugReportService {
  /// Submit a bug report to the backend server
  /// 
  /// Returns true if successful, false otherwise
  static Future<bool> submitBugReport({
    required String email,
    required String title,
    required String description,
    String? stepsToReproduce,
    required String deviceInfo,
    required String appVersion,
  }) async {
    try {
      AppLogger.info('Submitting bug report to backend...', tag: 'BugReport');

      final response = await http.post(
        Uri.parse(AppConstants.bugReportEndpoint),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'title': title,
          'description': description,
          'stepsToReproduce': stepsToReproduce ?? 'Not provided',
          'deviceInfo': deviceInfo,
          'appVersion': appVersion,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          AppLogger.success('Bug report submitted successfully', tag: 'BugReport');
          return true;
        } else {
          AppLogger.error(
            'Bug report submission failed: ${data['message'] ?? 'Unknown error'}',
            tag: 'BugReport',
          );
          return false;
        }
      } else if (response.statusCode == 429) {
        AppLogger.warning('Rate limit exceeded', tag: 'BugReport');
        return false;
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        AppLogger.error(
          'Validation failed: ${data['errors']?.join(', ') ?? 'Unknown validation error'}',
          tag: 'BugReport',
        );
        return false;
      } else {
        AppLogger.error(
          'Bug report submission failed with status: ${response.statusCode}',
          tag: 'BugReport',
        );
        return false;
      }
    } on SocketException catch (e) {
      AppLogger.error(
        'Network error - check internet connection',
        tag: 'BugReport',
        error: e,
      );
      return false;
    } on TimeoutException catch (e) {
      AppLogger.error(
        'Request timed out - server may be unreachable',
        tag: 'BugReport',
        error: e,
      );
      return false;
    } catch (e) {
      AppLogger.error(
        'Unexpected error submitting bug report',
        tag: 'BugReport',
        error: e,
      );
      return false;
    }
  }

  /// Check if the backend is healthy and reachable
  static Future<bool> checkBackendHealth() async {
    try {
      AppLogger.debug('Checking backend health...', tag: 'BugReport');

      final response = await http.get(
        Uri.parse(AppConstants.healthCheckEndpoint),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isHealthy = data['success'] == true;
        AppLogger.info(
          'Backend health: ${isHealthy ? "healthy" : "unhealthy"}',
          tag: 'BugReport',
        );
        return isHealthy;
      } else {
        AppLogger.warning('Backend health check failed', tag: 'BugReport');
        return false;
      }
    } catch (e) {
      AppLogger.error('Backend health check error', tag: 'BugReport', error: e);
      return false;
    }
  }
}