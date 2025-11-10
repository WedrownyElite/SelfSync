import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/app_logger.dart';

class EmailService {
  // Your production backend URL
  static const String _apiEndpoint = 'https://selfsyncapi.oddologyinc.com/api/bug-report';

  // Your API key from the backend .env file
  static const String _apiKey = '55c5fu25TXdlRczAkqbYKKb1U3ttRAIONyhPwEgIoWc=';

  /// Send a bug report email
  /// Returns true if successful, false otherwise
  static Future<bool> sendBugReport({
    required String userEmail,
    required String title,
    required String description,
    required String stepsToReproduce,
    required String deviceInfo,
    required String appVersion,
  }) async {
    try {
      AppLogger.info('Sending bug report to backend', tag: 'EmailService');

      final response = await http.post(
        Uri.parse(_apiEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-API-Key': _apiKey,
        },
        body: jsonEncode({
          'email': userEmail,
          'title': title,
          'description': description,
          'stepsToReproduce': stepsToReproduce,
          'deviceInfo': deviceInfo,
          'appVersion': appVersion,
        }),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timeout - backend not responding');
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body);
        final success = responseData['success'] ?? false;

        if (success) {
          AppLogger.info('Bug report sent successfully', tag: 'EmailService');
          return true;
        } else {
          final message = responseData['message'] ?? 'Unknown error';
          AppLogger.error(
            'Backend returned error: $message',
            tag: 'EmailService',
          );
          return false;
        }
      } else if (response.statusCode == 429) {
        AppLogger.warning(
          'Rate limit exceeded - too many requests',
          tag: 'EmailService',
        );
        return false;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        AppLogger.error(
          'Authentication failed - check API key',
          tag: 'EmailService',
        );
        return false;
      } else {
        AppLogger.error(
          'Failed to send bug report: ${response.statusCode} - ${response.body}',
          tag: 'EmailService',
        );
        return false;
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error sending bug report',
        error: e,
        stackTrace: stackTrace,
        tag: 'EmailService',
      );
      return false;
    }
  }

  /// Validate email format
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }
}