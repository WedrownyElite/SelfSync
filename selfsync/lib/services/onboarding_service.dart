import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';

class OnboardingService extends ChangeNotifier {
  static const String _privacyAcceptedKey = 'privacy_policy_accepted';
  static const String _tutorialCompletedKey = 'tutorial_completed';

  SharedPreferences? _prefs;
  bool _privacyAccepted = false;
  bool _tutorialCompleted = false;

  bool get privacyAccepted => _privacyAccepted;
  bool get tutorialCompleted => _tutorialCompleted;
  bool get shouldShowTutorial => _privacyAccepted && !_tutorialCompleted;

  OnboardingService() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _privacyAccepted = _prefs?.getBool(_privacyAcceptedKey) ?? false;
    _tutorialCompleted = _prefs?.getBool(_tutorialCompletedKey) ?? false;
    notifyListeners();
  }

  Future<void> acceptPrivacyPolicy() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(_privacyAcceptedKey, true);
    _privacyAccepted = true;
    notifyListeners();
    AppLogger.info('Privacy policy accepted', tag: 'OnboardingService');
  }

  Future<void> completeTutorial() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(_tutorialCompletedKey, true);
    _tutorialCompleted = true;
    notifyListeners();
    AppLogger.info('Tutorial completed', tag: 'OnboardingService');
  }

  Future<void> resetPrivacyPolicy() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(_privacyAcceptedKey);
    _privacyAccepted = false;
    notifyListeners();
    AppLogger.info('Privacy policy reset', tag: 'OnboardingService');
  }

  Future<void> resetTutorial() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(_tutorialCompletedKey);
    _tutorialCompleted = false;
    notifyListeners();
    AppLogger.info('Tutorial reset', tag: 'OnboardingService');
  }

  /// Reset all onboarding state (for account deletion)
  Future<void> resetAll() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(_privacyAcceptedKey);
    await _prefs!.remove(_tutorialCompletedKey);
    _privacyAccepted = false;
    _tutorialCompleted = false;
    notifyListeners();
    AppLogger.info('All onboarding state reset', tag: 'OnboardingService');
  }
}