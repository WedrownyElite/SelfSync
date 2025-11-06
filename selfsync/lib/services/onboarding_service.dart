import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService extends ChangeNotifier {
  static const String _hasCompletedOnboardingKey = 'has_completed_onboarding';
  static const String _hasCompletedTutorialKey = 'has_completed_tutorial';
  static const String _privacyAcceptedKey = 'privacy_policy_accepted';
  static const String _privacyAcceptedDateKey = 'privacy_accepted_date';

  bool _hasCompletedOnboarding = false;
  bool _hasCompletedTutorial = false;
  bool _privacyAccepted = false;
  DateTime? _privacyAcceptedDate;

  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  bool get hasCompletedTutorial => _hasCompletedTutorial;
  bool get privacyAccepted => _privacyAccepted;
  DateTime? get privacyAcceptedDate => _privacyAcceptedDate;

  /// Check if user should see tutorial
  /// Show tutorial if they haven't completed it yet
  bool get shouldShowTutorial => !_hasCompletedTutorial;

  OnboardingService() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    _hasCompletedOnboarding = prefs.getBool(_hasCompletedOnboardingKey) ?? false;
    _hasCompletedTutorial = prefs.getBool(_hasCompletedTutorialKey) ?? false;
    _privacyAccepted = prefs.getBool(_privacyAcceptedKey) ?? false;

    final dateString = prefs.getString(_privacyAcceptedDateKey);
    if (dateString != null) {
      _privacyAcceptedDate = DateTime.tryParse(dateString);
    }

    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _hasCompletedOnboarding = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasCompletedOnboardingKey, true);
    notifyListeners();
  }

  Future<void> completeTutorial() async {
    _hasCompletedTutorial = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasCompletedTutorialKey, true);
    notifyListeners();
  }

  Future<void> acceptPrivacyPolicy() async {
    _privacyAccepted = true;
    _privacyAcceptedDate = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_privacyAcceptedKey, true);
    await prefs.setString(_privacyAcceptedDateKey, _privacyAcceptedDate!.toIso8601String());

    notifyListeners();
  }

  /// Reset privacy policy acceptance
  Future<void> resetPrivacyPolicy() async {
    _privacyAccepted = false;
    _privacyAcceptedDate = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_privacyAcceptedKey, false);
    await prefs.remove(_privacyAcceptedDateKey);

    notifyListeners();
  }

  Future<void> resetOnboarding() async {
    _hasCompletedOnboarding = false;
    _hasCompletedTutorial = false;
    _privacyAccepted = false;
    _privacyAcceptedDate = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hasCompletedOnboardingKey);
    await prefs.remove(_hasCompletedTutorialKey);
    await prefs.remove(_privacyAcceptedKey);
    await prefs.remove(_privacyAcceptedDateKey);

    notifyListeners();
  }

  Future<void> resetTutorial() async {
    _hasCompletedTutorial = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hasCompletedTutorialKey);

    notifyListeners();
  }
}