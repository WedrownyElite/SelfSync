import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';

class ProfileStorageService extends ChangeNotifier {
  static const String _profilePictureKey = 'saved_profile_picture';
  static const String _displayNameKey = 'saved_display_name';

  SharedPreferences? _prefs;

  ProfileStorageService() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Save profile picture URL for later restoration
  Future<void> saveProfilePicture(String userId, String photoURL) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString('${_profilePictureKey}_$userId', photoURL);
    AppLogger.info('Saved profile picture for user $userId', tag: 'ProfileStorage');
  }

  /// Get saved profile picture URL
  Future<String?> getSavedProfilePicture(String userId) async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!.getString('${_profilePictureKey}_$userId');
  }

  /// Save display name for later restoration
  Future<void> saveDisplayName(String userId, String displayName) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString('${_displayNameKey}_$userId', displayName);
    AppLogger.info('Saved display name for user $userId', tag: 'ProfileStorage');
  }

  /// Get saved display name
  Future<String?> getSavedDisplayName(String userId) async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!.getString('${_displayNameKey}_$userId');
  }

  /// Clear saved profile data
  Future<void> clearSavedProfile(String userId) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove('${_profilePictureKey}_$userId');
    await _prefs!.remove('${_displayNameKey}_$userId');
    AppLogger.info('Cleared saved profile for user $userId', tag: 'ProfileStorage');
  }
}