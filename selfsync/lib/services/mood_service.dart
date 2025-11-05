import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mood_entry.dart';

class MoodService extends ChangeNotifier {
  final List<MoodEntry> _entries = [];
  final Set<String> _testDataIds = {};
  static const String _storageKey = 'mood_entries';
  static const String _hasLoadedSampleDataKey = 'has_loaded_sample_data';
  bool _isLoaded = false;

  List<MoodEntry> get entries => List.unmodifiable(_entries);

  /// Get entries excluding test data (for Mood Diary during onboarding)
  List<MoodEntry> get entriesExcludingTestData =>
      List.unmodifiable(_entries.where((e) => !_testDataIds.contains(e.id)));

  /// Check if we have test data
  bool get hasTestData => _testDataIds.isNotEmpty;

  MoodService() {
    _loadEntries();
  }

  /// Add a test data entry (for onboarding)
  void addTestEntry(String message, int moodRating, {DateTime? timestamp}) {
    final id = (timestamp ?? DateTime.now()).millisecondsSinceEpoch.toString();
    final entry = MoodEntry(
      id: id,
      message: message,
      moodRating: moodRating,
      timestamp: timestamp ?? DateTime.now(),
    );
    _entries.insert(0, entry);
    _testDataIds.add(id); // Mark as test data
    notifyListeners();
    // Don't save test data to storage
  }

  /// Clear all test data entries
  void clearTestData() {
    final count = _testDataIds.length;
    _entries.removeWhere((entry) => _testDataIds.contains(entry.id));
    _testDataIds.clear();
    notifyListeners();
    debugPrint('Cleared $count test data entries');
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
    int entryId = 0;

    // Define the date ranges
    final startDate2023 = DateTime(2023, 1, 1);
    final endDate2025 = DateTime(2025, 10, 27);
    final totalDays = endDate2025.difference(startDate2023).inDays;

    // Calculate days to scatter (excluding October 2025)
    final daysToScatter = totalDays - 27; // Exclude October 2025 days

    for (int i = 0; i < 273; i++) {
      // Pick a random day between 2023-01-01 and 2025-09-30
      final randomDayOffset = random.nextInt(daysToScatter);
      var randomDate = startDate2023.add(Duration(days: randomDayOffset));

      // Skip if we accidentally land in October 2025
      while (randomDate.year == 2025 && randomDate.month == 10) {
        final newOffset = random.nextInt(daysToScatter);
        randomDate = startDate2023.add(Duration(days: newOffset));
      }

      // Random time during the day (6 AM to 11 PM)
      final hourOffset = random.nextInt(17) + 6;
      final minuteOffset = random.nextInt(60);

      final entryTime = DateTime(
        randomDate.year,
        randomDate.month,
        randomDate.day,
        hourOffset,
        minuteOffset,
      );

      // Generate mood rating with varied distribution
      // 10% very low (1-3), 30% low-medium (4-5), 40% good (6-7), 20% excellent (8-10)
      final moodDist = random.nextInt(100);
      int moodRating;
      if (moodDist < 10) {
        moodRating = random.nextInt(3) + 1; // 1-3
      } else if (moodDist < 40) {
        moodRating = random.nextInt(2) + 4; // 4-5
      } else if (moodDist < 80) {
        moodRating = random.nextInt(2) + 6; // 6-7
      } else {
        moodRating = random.nextInt(3) + 8; // 8-10
      }

      _entries.add(
        MoodEntry(
          id: 'entry_${entryId++}',
          message: _generateSampleMessage(moodRating),
          moodRating: moodRating,
          timestamp: entryTime,
        ),
      );
    }

    // Generate daily entries for October 1-27, 2025
    // 1-2 entries per day to create realistic daily tracking
    for (int day = 1; day <= 27; day++) {
      final entriesThisDay = random.nextBool() ? 1 : 2;

      for (int j = 0; j < entriesThisDay; j++) {
        // Varied times throughout the day
        final hourOffset = j == 0
            ? random.nextInt(6) + 8  // Morning: 8 AM - 1 PM
            : random.nextInt(7) + 15; // Evening: 3 PM - 9 PM
        final minuteOffset = random.nextInt(60);

        final entryTime = DateTime(
          2025,
          10,
          day,
          hourOffset,
          minuteOffset,
        );

        // October entries trend slightly higher (simulating recent improvement)
        final baseMood = 7;
        final variation = random.nextInt(5) - 2; // -2 to +2
        final moodRating = (baseMood + variation).clamp(1, 10);

        _entries.add(
          MoodEntry(
            id: 'entry_${entryId++}',
            message: _generateSampleMessage(moodRating),
            moodRating: moodRating,
            timestamp: entryTime,
          ),
        );
      }
    }

    // Sort entries by timestamp (newest first)
    _entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final oldestEntry = _entries.last;
    final newestEntry = _entries.first;
    debugPrint('Generated ${_entries.length} static entries');
    debugPrint('Date range: ${oldestEntry.timestamp.toString().split(' ')[0]} to ${newestEntry.timestamp.toString().split(' ')[0]}');
    debugPrint('October 2025: Complete daily coverage (Oct 1-27)');
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

  void addEntry(String message, int moodRating, {DateTime? timestamp}) {
    final entry = MoodEntry(
      id: (timestamp ?? DateTime.now()).millisecondsSinceEpoch.toString(),
      message: message,
      moodRating: moodRating,
      timestamp: timestamp ?? DateTime.now(),
    );
    _entries.insert(0, entry);
    notifyListeners();
    _saveEntries();
  }

  /// Clear all entries (used for onboarding cleanup)
  void clearAllEntries() {
    _entries.clear();
    _saveEntries();
    notifyListeners();
    debugPrint('All mood entries cleared');
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
    // Keep the flag so sample data doesn't auto-generate again
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