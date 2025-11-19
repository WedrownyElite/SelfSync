import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/mood_entry.dart';
import '../utils/app_logger.dart';

class CloudBackupService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const String _autoBackupKey = 'auto_backup_enabled';
  static const String _lastBackupKey = 'last_backup_timestamp';
  static const String _hasBeenAskedKey = 'cloud_backup_has_been_asked';

  SharedPreferences? _prefs;

  bool _autoBackupEnabled = false;
  DateTime? _lastBackupTime;
  bool _isBackingUp = false;
  bool _isRestoring = false;

  bool get autoBackupEnabled => _autoBackupEnabled;
  DateTime? get lastBackupTime => _lastBackupTime;
  bool get isBackingUp => _isBackingUp;
  bool get isRestoring => _isRestoring;

  CloudBackupService() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoBackupEnabled = prefs.getBool(_autoBackupKey) ?? false;

      final lastBackupMillis = prefs.getInt(_lastBackupKey);
      if (lastBackupMillis != null) {
        _lastBackupTime = DateTime.fromMillisecondsSinceEpoch(lastBackupMillis);
      }

      notifyListeners();
      AppLogger.info('Loaded backup preferences - Auto backup: $_autoBackupEnabled', tag: 'CloudBackup');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load backup preferences', error: e, stackTrace: stackTrace, tag: 'CloudBackup');
    }
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoBackupKey, enabled);

      _autoBackupEnabled = enabled;
      notifyListeners();

      AppLogger.info('Auto backup ${enabled ? "enabled" : "disabled"}', tag: 'CloudBackup');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to set auto backup preference', error: e, stackTrace: stackTrace, tag: 'CloudBackup');
    }
  }

  Future<void> _saveLastBackupTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      await prefs.setInt(_lastBackupKey, now.millisecondsSinceEpoch);

      _lastBackupTime = now;
      notifyListeners();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save last backup time', error: e, stackTrace: stackTrace, tag: 'CloudBackup');
    }
  }

  /// Backup mood entries to cloud
  Future<bool> backupToCloud(List<MoodEntry> entries) async {
    final user = _auth.currentUser;
    if (user == null) {
      AppLogger.warning('Cannot backup - user not signed in', tag: 'CloudBackup');
      return false;
    }

    if (_isBackingUp) {
      AppLogger.warning('Backup already in progress', tag: 'CloudBackup');
      return false;
    }

    try {
      _isBackingUp = true;
      notifyListeners();

      AppLogger.info('Starting cloud backup for ${entries.length} entries', tag: 'CloudBackup');

      // Convert entries to JSON
      final backupData = {
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'entries': entries.map((e) => e.toJson()).toList(),
      };

      final jsonString = jsonEncode(backupData);
      final jsonBytes = utf8.encode(jsonString);

      // Upload to Firebase Storage
      final fileName = 'mood_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final ref = _storage.ref().child('users/${user.uid}/backups/$fileName');

      await ref.putData(
        Uint8List.fromList(jsonBytes),
        SettableMetadata(
          contentType: 'application/json',
          customMetadata: {
            'entryCount': entries.length.toString(),
            'appVersion': '1.0.0',
          },
        ),
      );

      await _saveLastBackupTime();

      AppLogger.success('Cloud backup completed successfully', tag: 'CloudBackup');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Cloud backup failed', error: e, stackTrace: stackTrace, tag: 'CloudBackup');
      return false;
    } finally {
      _isBackingUp = false;
      notifyListeners();
    }
  }

  /// Check if cloud backup exists
  Future<bool> hasCloudBackup() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final ref = _storage.ref().child('users/${user.uid}/backups');
      final listResult = await ref.listAll();

      return listResult.items.isNotEmpty;
    } catch (e) {
      AppLogger.error('Failed to check for cloud backup', error: e, tag: 'CloudBackup');
      return false;
    }
  }

  /// Get backup metadata
  Future<BackupMetadata?> getLatestBackupMetadata() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final ref = _storage.ref().child('users/${user.uid}/backups');
      final listResult = await ref.listAll();

      if (listResult.items.isEmpty) return null;

      // Sort by creation time (newest first)
      listResult.items.sort((a, b) => b.name.compareTo(a.name));

      final latestRef = listResult.items.first;
      final metadata = await latestRef.getMetadata();

      return BackupMetadata(
        fileName: latestRef.name,
        createdAt: metadata.timeCreated ?? DateTime.now(),
        sizeBytes: metadata.size ?? 0,
        entryCount: int.tryParse(metadata.customMetadata?['entryCount'] ?? '0') ?? 0,
      );
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get backup metadata', error: e, stackTrace: stackTrace, tag: 'CloudBackup');
      return null;
    }
  }

  /// Restore mood entries from cloud
  Future<List<MoodEntry>?> restoreFromCloud() async {
    final user = _auth.currentUser;
    if (user == null) {
      AppLogger.warning('Cannot restore - user not signed in', tag: 'CloudBackup');
      return null;
    }

    if (_isRestoring) {
      AppLogger.warning('Restore already in progress', tag: 'CloudBackup');
      return null;
    }

    try {
      _isRestoring = true;
      notifyListeners();

      AppLogger.info('Starting cloud restore', tag: 'CloudBackup');

      // Get the latest backup file
      final ref = _storage.ref().child('users/${user.uid}/backups');
      final listResult = await ref.listAll();

      if (listResult.items.isEmpty) {
        AppLogger.warning('No backup files found', tag: 'CloudBackup');
        return null;
      }

      // Sort by creation time (newest first)
      listResult.items.sort((a, b) => b.name.compareTo(a.name));
      final latestRef = listResult.items.first;

      // Download and parse backup
      final downloadData = await latestRef.getData();
      if (downloadData == null) {
        AppLogger.error('Failed to download backup data', tag: 'CloudBackup');
        return null;
      }

      final jsonString = utf8.decode(downloadData);
      final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

      final entriesJson = backupData['entries'] as List<dynamic>;
      final entries = entriesJson
          .map((e) => MoodEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      AppLogger.success('Cloud restore completed - ${entries.length} entries', tag: 'CloudBackup');
      return entries;
    } catch (e, stackTrace) {
      AppLogger.error('Cloud restore failed', error: e, stackTrace: stackTrace, tag: 'CloudBackup');
      return null;
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  /// Delete all cloud backups
  Future<bool> deleteAllCloudBackups() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final ref = _storage.ref().child('users/${user.uid}/backups');
      final listResult = await ref.listAll();

      for (final item in listResult.items) {
        await item.delete();
      }

      AppLogger.success('All cloud backups deleted', tag: 'CloudBackup');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to delete cloud backups', error: e, stackTrace: stackTrace, tag: 'CloudBackup');
      return false;
    }
  }

  bool get hasBeenAskedAboutBackup {
    return _prefs?.getBool(_hasBeenAskedKey) ?? false;
  }

  Future<void> setHasBeenAskedAboutBackup(bool value) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(_hasBeenAskedKey, value);
    AppLogger.info('Has been asked about backup set to: $value', tag: 'CloudBackupService');
  }

  Future<void> resetBackupPreferences() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(_hasBeenAskedKey);
    await _prefs!.remove(_autoBackupKey);
    AppLogger.info('Backup preferences reset', tag: 'CloudBackupService');
  }
}

class BackupMetadata {
  final String fileName;
  final DateTime createdAt;
  final int sizeBytes;
  final int entryCount;

  BackupMetadata({
    required this.fileName,
    required this.createdAt,
    required this.sizeBytes,
    required this.entryCount,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}