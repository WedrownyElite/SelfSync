# Self Sync - Quick Reference Card

## 🚀 Quick Start
```bash
cd selfsync
flutter pub get
flutter run
```

## 📁 File Structure
```
lib/
├── main.dart                  → App entry, theme, routing
├── models/
│   └── mood_entry.dart        → MoodEntry class, emojis
├── services/
│   └── mood_service.dart      → Data management, analytics
├── screens/
│   ├── home_screen.dart       → Main menu (2 buttons)
│   ├── mood_log_screen.dart   → Chat-style logging
│   └── trends_screen.dart     → Analytics dashboard
└── widgets/
    └── page_transition.dart   → Custom transitions
```

## 🎨 Key Colors
```dart
Primary:    #6C63FF  // Purple
Secondary:  #FF6B9D  // Pink
Background: #F8F9FA  // Light gray
Surface:    #FFFFFF  // White
```

## 🎭 Mood Scale
```
1-2:  😢😞  Struggling  (Red)
3-4:  😔😕  Low         (Orange)
5-6:  😐🙂  Okay        (Amber)
7-8:  😊😄  Good        (Light Green)
9-10: 😁🤩  Excellent   (Green)
```

## 🧭 Navigation
```
Home
├─→ Log Mood (Slide transition)
└─→ View Trends (Scale transition)
```

## ✏️ Quick Customization

### Change Primary Color
`lib/main.dart` line ~41:
```dart
seedColor: const Color(0xFF6C63FF),
```

### Modify Mood Emojis
`lib/models/mood_entry.dart` line ~30-42:
```dart
static String getMoodEmoji(int rating) {
  switch (rating) {
    case 1: return '😢';
    // ...
  }
}
```

### Remove Demo Data
`lib/services/mood_service.dart` line ~14:
```dart
MoodService() {
  // _loadSampleData(); // Comment out this line
}
```

## 📊 Features Checklist
- ✅ Home screen with 2 gradient buttons
- ✅ Chat-style mood logging
- ✅ Mood slider (1-10) with live emoji
- ✅ Timestamp on every entry
- ✅ Analytics dashboard
- ✅ Time range selector (7D, 30D, 3M, 1Y, Lifetime)
- ✅ Average mood calculation
- ✅ Best/toughest day display
- ✅ Peak time of day
- ✅ Mood trend chart
- ✅ Activity calendar heatmap
- ✅ Custom page transitions
- ✅ Smooth animations

## 🔧 Common Commands
```bash
# Run app
flutter run

# Run on specific device
flutter run -d chrome      # Web
flutter run -d android     # Android
flutter run -d ios         # iOS

# Hot reload
# Press 'r' in terminal

# Clean build
flutter clean
flutter pub get

# Build release
flutter build apk          # Android APK
flutter build ios          # iOS
flutter build web          # Web
```

## 🐛 Troubleshooting

### Package errors
```bash
flutter clean && flutter pub get
```

### Gradle issues (Android)
- Ensure JDK 17+
- Check Android SDK API 33+

### iOS issues
```bash
cd ios && pod install && cd ..
```

## 📱 Screen Specs

### Home Screen
- 2 gradient CTA buttons
- Fade-in animation
- Clean typography

### Mood Log
- Chat bubbles
- Emoji avatars
- Expandable slider
- Real-time feedback

### Trends
- Time range tabs
- 4 stat cards
- Line chart
- Activity heatmap

## 🎬 Animation Timings
```
Page transitions:  350-450ms
Entry animations:  400-600ms
Micro-interactions: 200-300ms
Curve: easeOutCubic (natural motion)
```

## 📚 Documentation
1. `README.md` - Overview
2. `SETUP_GUIDE.md` - Installation
3. `UI_DESIGN.md` - Design docs
4. `SCREEN_FLOW.md` - User journey
5. `PROJECT_SUMMARY.md` - Complete summary
6. `QUICK_REFERENCE.md` - This file!

## 💡 Tips
- Use `const` constructors for performance
- Keep widgets small and focused
- Test on multiple screen sizes
- Follow Material Design 3 guidelines
- Use descriptive variable names

## 🔗 Useful Links
- Flutter Docs: https://docs.flutter.dev
- Material Design: https://m3.material.io
- Dart Packages: https://pub.dev
- Flutter GitHub: https://github.com/flutter

## 🎯 Next Steps
1. Run the app: `flutter run`
2. Explore the 3 screens
3. Add your own mood entry
4. Check analytics in trends
5. Customize colors/emojis
6. Read full documentation
7. Build something awesome!

---

**Need help?** Check the full docs or open an issue on GitHub!

*Quick, clean, and ready to code!* ⚡