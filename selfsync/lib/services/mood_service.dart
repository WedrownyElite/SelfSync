import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mood_entry.dart';

class MoodService extends ChangeNotifier {
  final List<MoodEntry> _entries = [];
  static const String _storageKey = 'mood_entries';
  static const String _hasLoadedSampleDataKey = 'has_loaded_sample_data';
  bool _isLoaded = false;

  List<MoodEntry> get entries => List.unmodifiable(_entries);

  MoodService() {
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    if (_isLoaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? entriesJson = prefs.getString(_storageKey);
      final bool hasLoadedSampleData = prefs.getBool(_hasLoadedSampleDataKey) ?? false;

      if (entriesJson != null && entriesJson.isNotEmpty) {
        // Load existing data
        final List<dynamic> decoded = jsonDecode(entriesJson);
        _entries.clear();
        _entries.addAll(
          decoded.map((json) => MoodEntry.fromJson(json as Map<String, dynamic>)),
        );
        _entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        debugPrint('Loaded ${_entries.length} entries from storage');
      } else if (!hasLoadedSampleData) {
        // First time load - generate sample data
        debugPrint('First time load - generating sample data');
        _loadSampleData();
        await _saveEntries();
        await prefs.setBool(_hasLoadedSampleDataKey, true);
        debugPrint('Sample data saved - ${_entries.length} entries');
      }

      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading entries: $e');
      // If loading fails, use sample data
      _loadSampleData();
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _saveEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> jsonList =
      _entries.map((entry) => entry.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
      debugPrint('Saved ${_entries.length} entries to storage');
    } catch (e) {
      debugPrint('Error saving entries: $e');
    }
  }

  void _loadSampleData() {
    final random = Random(42); // Use seed for consistent data

    // Generate data ending TODAY and going back 100 days
    final today = DateTime.now();
    final startDate = today.subtract(const Duration(days: 100));

    // Generate 100 days of data
    for (int i = 0; i <= 100; i++) {
      final dayDate = startDate.add(Duration(days: i));

      // Skip future dates
      if (dayDate.isAfter(today)) continue;

      // Generate 1-3 entries per day
      final entriesPerDay = random.nextInt(3) + 1;

      for (int j = 0; j < entriesPerDay; j++) {
        final hourOffset = random.nextInt(12) + 8; // Between 8 AM and 8 PM
        final entryTime = DateTime(
          dayDate.year,
          dayDate.month,
          dayDate.day,
          hourOffset,
          random.nextInt(60),
        );

        // Skip if this would be in the future
        if (entryTime.isAfter(today)) continue;

        // Generate mood rating with some variation (4-9 range mostly)
        final baseMood = 6;
        final variation = random.nextInt(5) - 2; // -2 to +2
        final moodRating = (baseMood + variation).clamp(1, 10);

        _entries.add(
          MoodEntry(
            id: 'sample_${i}_$j',
            message: _generateSampleMessage(moodRating),
            moodRating: moodRating,
            timestamp: entryTime,
          ),
        );
      }
    }

    // Sort entries by timestamp (newest first)
    _entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    debugPrint('Generated ${_entries.length} sample entries from ${startDate.toString().split(' ')[0]} to ${today.toString().split(' ')[0]}');
  }

  String _generateSampleMessage(int mood) {
    final messages = {
      1: ['Feeling really down today', 'Having a tough time', 'Struggling today'],
      2: ['Not a great day', 'Feeling low', 'Could be better'],
      3: ['Feeling a bit off', 'Not my best day', 'A bit down'],
      4: ['Okay, but not great', 'Meh kind of day', 'Could be worse'],
      5: ['Feeling neutral', 'Just okay', 'Nothing special'],
      6: ['Pretty good today', 'Feeling alright', 'Decent day'],
      7: ['Having a good day', 'Feeling positive', 'Things are good'],
      8: ['Great day!', 'Feeling really good', 'Happy today'],
      9: ['Excellent day!', 'Feeling amazing', 'So happy!'],
      10: ['Best day ever!', 'Absolutely incredible!', 'On top of the world!'],
    };

    final messageList = messages[mood] ?? ['Feeling okay'];
    return messageList[Random().nextInt(messageList.length)];
  }

  void addEntry(String message, int moodRating) {
    final entry = MoodEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: message,
      moodRating: moodRating,
      timestamp: DateTime.now(),
    );
    _entries.insert(0, entry);
    notifyListeners();
    _saveEntries(); // Save after adding
  }

  void deleteEntry(String id) {
    _entries.removeWhere((entry) => entry.id == id);
    notifyListeners();
    _saveEntries(); // Save after deleting
  }

  void updateEntry(String id, String newMessage, int newMoodRating) {
    final index = _entries.indexWhere((entry) => entry.id == id);
    if (index != -1) {
      _entries[index] = MoodEntry(
        id: id,
        message: newMessage,
        moodRating: newMoodRating,
        timestamp: _entries[index].timestamp,
      );
      notifyListeners();
      _saveEntries(); // Save after updating
    }
  }

  List<MoodEntry> getEntriesInRange(DateTime start, DateTime end) {
    return _entries.where((entry) {
      return entry.timestamp.isAfter(start) && entry.timestamp.isBefore(end);
    }).toList();
  }

  double getAverageMood(DateTime start, DateTime end) {
    final rangeEntries = getEntriesInRange(start, end);
    if (rangeEntries.isEmpty) return 0;

    final sum = rangeEntries.fold<int>(
      0,
          (sum, entry) => sum + entry.moodRating,
    );
    return sum / rangeEntries.length;
  }

  MoodEntry? getBestDay(DateTime start, DateTime end) {
    final rangeEntries = getEntriesInRange(start, end);
    if (rangeEntries.isEmpty) return null;

    rangeEntries.sort((a, b) => b.moodRating.compareTo(a.moodRating));
    return rangeEntries.first;
  }

  MoodEntry? getToughestDay(DateTime start, DateTime end) {
    final rangeEntries = getEntriesInRange(start, end);
    if (rangeEntries.isEmpty) return null;

    rangeEntries.sort((a, b) => a.moodRating.compareTo(b.moodRating));
    return rangeEntries.first;
  }

  int getPeakTimeOfDay(DateTime start, DateTime end) {
    final rangeEntries = getEntriesInRange(start, end);
    if (rangeEntries.isEmpty) return 12;

    final hourCounts = <int, List<int>>{};

    for (var entry in rangeEntries) {
      final hour = entry.timestamp.hour;
      hourCounts.putIfAbsent(hour, () => []);
      hourCounts[hour]!.add(entry.moodRating);
    }

    int peakHour = 12;
    double highestAvg = 0;

    hourCounts.forEach((hour, ratings) {
      final avg = ratings.reduce((a, b) => a + b) / ratings.length;
      if (avg > highestAvg) {
        highestAvg = avg;
        peakHour = hour;
      }
    });

    return peakHour;
  }

  Map<DateTime, int> getActivityCalendar(DateTime start, DateTime end) {
    final rangeEntries = getEntriesInRange(start, end);
    final calendar = <DateTime, int>{};

    for (var entry in rangeEntries) {
      final date = DateTime(
        entry.timestamp.year,
        entry.timestamp.month,
        entry.timestamp.day,
      );
      calendar[date] = (calendar[date] ?? 0) + 1;
    }

    return calendar;
  }

  // Clear all data (for debugging/testing)
  Future<void> clearAllData() async {
    _entries.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    await prefs.remove(_hasLoadedSampleDataKey);
    notifyListeners();
    debugPrint('All data cleared');
  }

  // Force reload sample data (for debugging/testing)
  Future<void> reloadSampleData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hasLoadedSampleDataKey);
    _entries.clear();
    _isLoaded = false;
    await _loadEntries();
    debugPrint('Sample data reloaded');
  }

  /// Returns the number of consecutive days up to today
  /// Returns the number of consecutive days up to today
  int getCurrentStreak() {
    if (_entries.isEmpty) return 0;

    // Get unique days with entries (normalized to date only)
    final uniqueDays = _entries.map((entry) {
      return DateTime(
        entry.timestamp.year,
        entry.timestamp.month,
        entry.timestamp.day,
      );
    }).toSet().toList()
      ..sort((a, b) => b.compareTo(a)); // Sort newest first

    if (uniqueDays.isEmpty) return 0;

    // Check if today has an entry
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);

    int streak = 0;
    DateTime checkDate = todayNormalized;

    // Count backwards from today
    for (final entryDate in uniqueDays) {
      if (entryDate.isAtSameMomentAs(checkDate)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (entryDate.isBefore(checkDate)) {
        // Gap found - stop counting
        break;
      }
    }

    return streak;
  }

  /// Calculate the best (longest) streak in history
  /// Returns the longest consecutive day streak ever achieved
  int getBestStreak() {
    if (_entries.isEmpty) return 0;

    // Get unique days with entries (normalized to date only)
    final uniqueDays = _entries.map((entry) {
      return DateTime(
        entry.timestamp.year,
        entry.timestamp.month,
        entry.timestamp.day,
      );
    }).toSet().toList()
      ..sort(); // Sort oldest first for best streak calculation

    if (uniqueDays.isEmpty) return 0;
    if (uniqueDays.length == 1) return 1;

    int bestStreak = 1;
    int currentStreak = 1;

    for (int i = 1; i < uniqueDays.length; i++) {
      final daysDiff = uniqueDays[i].difference(uniqueDays[i - 1]).inDays;

      if (daysDiff == 1) {
        // Consecutive day
        currentStreak++;
        if (currentStreak > bestStreak) {
          bestStreak = currentStreak;
        }
      } else {
        // Gap found - reset streak
        currentStreak = 1;
      }
    }

    return bestStreak;
  }
}