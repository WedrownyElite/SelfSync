// lib/models/mood_entry.dart
// ─────────────────────────────────────────────────────────────
//  VibeCheck
//  Copyright (c) 2025 OddologyInc. All rights reserved.
// ─────────────────────────────────────────────────────────────

class MoodEntry {
  final String id;
  final String message;
  final int moodRating; // 1-10
  final DateTime timestamp;
  final List<String> emotions; // New field for emotions
  final List<String> activities; // For future use
  final String? location; // For future use
  final String? weather; // For future use

  MoodEntry({
    required this.id,
    required this.message,
    required this.moodRating,
    required this.timestamp,
    this.emotions = const [],
    this.activities = const [],
    this.location,
    this.weather,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message': message,
      'moodRating': moodRating,
      'timestamp': timestamp.toIso8601String(),
      'emotions': emotions,
      'activities': activities,
      'location': location,
      'weather': weather,
    };
  }

  factory MoodEntry.fromJson(Map<String, dynamic> json) {
    return MoodEntry(
      id: json['id'] as String,
      message: json['message'] as String,
      moodRating: json['moodRating'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      emotions: (json['emotions'] as List<dynamic>?)?.cast<String>() ?? [],
      activities: (json['activities'] as List<dynamic>?)?.cast<String>() ?? [],
      location: json['location'] as String?,
      weather: json['weather'] as String?,
    );
  }

  static String getMoodEmoji(int rating) {
    switch (rating) {
      case 1:
        return '😢';
      case 2:
        return '😞';
      case 3:
        return '😔';
      case 4:
        return '😕';
      case 5:
        return '😐';
      case 6:
        return '🙂';
      case 7:
        return '😊';
      case 8:
        return '😄';
      case 9:
        return '😁';
      case 10:
        return '🤩';
      default:
        return '😐';
    }
  }

  static String getMoodLabel(int rating) {
    if (rating <= 2) return 'Struggling';
    if (rating <= 4) return 'Low';
    if (rating <= 6) return 'Okay';
    if (rating <= 8) return 'Good';
    return 'Excellent';
  }
}

// Emotion data with positioning on energy/valence chart
class Emotion {
  final String name;
  final double energy; // -1 (calm) to 1 (energized)
  final double valence; // -1 (unpleasant) to 1 (pleasant)
  final String emoji;

  const Emotion({
    required this.name,
    required this.energy,
    required this.valence,
    required this.emoji,
  });

  static const List<Emotion> allEmotions = [
    // Energized + Pleasant (top right)
    Emotion(name: 'Excited', energy: 0.8, valence: 0.8, emoji: '🤗'),
    Emotion(name: 'Lively', energy: 0.6, valence: 0.7, emoji: '😃'),
    Emotion(name: 'Happy', energy: 0.5, valence: 0.9, emoji: '😊'),
    Emotion(name: 'Cheerful', energy: 0.4, valence: 0.8, emoji: '😄'),

    // Energized + Unpleasant (top left)
    Emotion(name: 'Tense', energy: 0.9, valence: -0.7, emoji: '😬'),
    Emotion(name: 'Nervous', energy: 0.7, valence: -0.6, emoji: '😰'),
    Emotion(name: 'Irritated', energy: 0.6, valence: -0.8, emoji: '😤'),
    Emotion(name: 'Annoyed', energy: 0.5, valence: -0.7, emoji: '😒'),

    // Calm + Unpleasant (bottom left)
    Emotion(name: 'Bored', energy: -0.5, valence: -0.5, emoji: '😑'),
    Emotion(name: 'Weary', energy: -0.6, valence: -0.6, emoji: '😔'),
    Emotion(name: 'Gloomy', energy: -0.7, valence: -0.8, emoji: '😞'),
    Emotion(name: 'Sad', energy: -0.6, valence: -0.9, emoji: '😢'),

    // Calm + Pleasant (bottom right)
    Emotion(name: 'Carefree', energy: -0.3, valence: 0.6, emoji: '😌'),
    Emotion(name: 'Relaxed', energy: -0.5, valence: 0.7, emoji: '😊'),
    Emotion(name: 'Calm', energy: -0.7, valence: 0.6, emoji: '😇'),
    Emotion(name: 'Serene', energy: -0.8, valence: 0.8, emoji: '🥰'),
  ];
}