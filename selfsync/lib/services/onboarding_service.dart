import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing onboarding flow and privacy acceptance
class OnboardingService extends ChangeNotifier {
  static const String _hasCompletedOnboardingKey = 'has_completed_onboarding';
  static const String _privacyAcceptedKey = 'privacy_policy_accepted';
  static const String _privacyAcceptedDateKey = 'privacy_accepted_date';

  bool _hasCompletedOnboarding = false;
  bool _privacyAccepted = false;
  DateTime? _privacyAcceptedDate;

  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  bool get privacyAccepted => _privacyAccepted;
  DateTime? get privacyAcceptedDate => _privacyAcceptedDate;

  OnboardingService() {
    _loadPreferences();
  }

  /// Load saved onboarding state
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    _hasCompletedOnboarding = prefs.getBool(_hasCompletedOnboardingKey) ?? false;
    _privacyAccepted = prefs.getBool(_privacyAcceptedKey) ?? false;

    final dateString = prefs.getString(_privacyAcceptedDateKey);
    if (dateString != null) {
      _privacyAcceptedDate = DateTime.tryParse(dateString);
    }

    notifyListeners();
  }

  /// Mark onboarding as completed
  Future<void> completeOnboarding() async {
    _hasCompletedOnboarding = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasCompletedOnboardingKey, true);
    notifyListeners();
  }

  /// Accept privacy policy
  Future<void> acceptPrivacyPolicy() async {
    _privacyAccepted = true;
    _privacyAcceptedDate = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_privacyAcceptedKey, true);
    await prefs.setString(_privacyAcceptedDateKey, _privacyAcceptedDate!.toIso8601String());

    notifyListeners();
  }

  /// Reset onboarding (for testing or user request)
  Future<void> resetOnboarding() async {
    _hasCompletedOnboarding = false;
    _privacyAccepted = false;
    _privacyAcceptedDate = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hasCompletedOnboardingKey);
    await prefs.remove(_privacyAcceptedKey);
    await prefs.remove(_privacyAcceptedDateKey);

    notifyListeners();
  }
}