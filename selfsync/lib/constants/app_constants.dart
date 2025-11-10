import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // App metadata
  static String get appVersion => dotenv.env['APP_VERSION'] ?? 'Unknown';

  // Backend configuration
  static String get backendUrl => dotenv.env['BACKEND_URL'] ?? 'http://localhost:3001';

  // API endpoints
  static String get bugReportEndpoint => '$backendUrl/api/bug-report';
  static String get healthCheckEndpoint => '$backendUrl/health';
}