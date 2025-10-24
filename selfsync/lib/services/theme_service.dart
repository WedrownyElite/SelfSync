import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing app theme preferences
class ThemeService extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _colorGradientKey = 'color_gradient';

  ThemeMode _themeMode = ThemeMode.system;
  ColorGradientOption _selectedGradient = ColorGradientOption.purple;

  ThemeMode get themeMode => _themeMode;
  ColorGradientOption get selectedGradient => _selectedGradient;

  ThemeService() {
    _loadPreferences();
  }

  /// Load saved preferences from storage
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // Load theme mode
    final themeModeString = prefs.getString(_themeModeKey);
    if (themeModeString != null) {
      _themeMode = ThemeMode.values.firstWhere(
            (mode) => mode.toString() == themeModeString,
        orElse: () => ThemeMode.system,
      );
    }

    // Load color gradient
    final gradientString = prefs.getString(_colorGradientKey);
    if (gradientString != null) {
      _selectedGradient = ColorGradientOption.values.firstWhere(
            (gradient) => gradient.toString() == gradientString,
        orElse: () => ColorGradientOption.purple,
      );
    }

    notifyListeners();
  }

  /// Change theme mode (light, dark, system)
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.toString());
    notifyListeners();
  }

  /// Change color gradient option
  Future<void> setColorGradient(ColorGradientOption gradient) async {
    _selectedGradient = gradient;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_colorGradientKey, gradient.toString());
    notifyListeners();
  }

  /// Get light theme data with selected gradient colors
  ThemeData getLightTheme() {
    final colors = _selectedGradient.colors;

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.primary,
        secondary: colors.secondary,
        surface: Colors.white,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      useMaterial3: true,
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: null, // Will use primary color
        unselectedItemColor: Colors.black54,
      ),
    );
  }

  /// Get dark theme data with selected gradient colors
  ThemeData getDarkTheme() {
    final colors = _selectedGradient.colors;

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.primary,
        secondary: colors.secondary,
        surface: const Color(0xFF1E1E1E),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      useMaterial3: true,
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1E1E1E),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white),
        bodySmall: TextStyle(color: Colors.white70),
        titleLarge: TextStyle(color: Colors.white),
        titleMedium: TextStyle(color: Colors.white),
        titleSmall: TextStyle(color: Colors.white),
      ),
    );
  }

  /// Get gradient for mood ratings (bad to good)
  List<Color> getMoodGradient() {
    return _selectedGradient.colors.moodGradient;
  }

  /// Get primary color for current gradient
  Color getPrimaryColor() {
    return _selectedGradient.colors.primary;
  }

  /// Get secondary color for current gradient
  Color getSecondaryColor() {
    return _selectedGradient.colors.secondary;
  }
}

/// Color gradient options for the app
enum ColorGradientOption {
  purple,
  blue,
  teal,
  orange,
  pink,
}

extension ColorGradientExtension on ColorGradientOption {
  GradientColors get colors {
    switch (this) {
      case ColorGradientOption.purple:
        return GradientColors(
          name: 'Classic',
          primary: const Color(0xFF6C63FF),
          secondary: const Color(0xFFFF6B9D),
          moodGradient: [
            const Color(0xFFEF5350), // 1-2: Red (struggling)
            const Color(0xFFFF7043), // 3-4: Red-Orange (low)
            const Color(0xFFFDD835), // 5-6: Yellow (okay)
            const Color(0xFF9CCC65), // 7-8: Light Green (good)
            const Color(0xFF66BB6A), // 9-10: Green (excellent)
          ],
        );
      case ColorGradientOption.blue:
        return GradientColors(
          name: 'Ocean Depths',
          primary: const Color(0xFF2196F3),
          secondary: const Color(0xFF00BCD4),
          moodGradient: [
            const Color(0xFF1565C0), // 1-2: Deep Blue (struggling)
            const Color(0xFF1976D2), // 3-4: Blue (low)
            const Color(0xFF42A5F5), // 5-6: Light Blue (okay)
            const Color(0xFF4DD0E1), // 7-8: Cyan (good)
            const Color(0xFF80DEEA), // 9-10: Light Cyan (excellent)
          ],
        );
      case ColorGradientOption.teal:
        return GradientColors(
          name: 'Forest Zen',
          primary: const Color(0xFF009688),
          secondary: const Color(0xFF4CAF50),
          moodGradient: [
            const Color(0xFF5D4037), // 1-2: Brown (struggling)
            const Color(0xFF795548), // 3-4: Light Brown (low)
            const Color(0xFFAED581), // 5-6: Light Green (okay)
            const Color(0xFF4CAF50), // 7-8: Green (good)
            const Color(0xFF00897B), // 9-10: Teal (excellent)
          ],
        );
      case ColorGradientOption.orange:
        return GradientColors(
          name: 'Sunrise',
          primary: const Color(0xFFFF5722),
          secondary: const Color(0xFFFFB300),
          moodGradient: [
            const Color(0xFF8E24AA), // 1-2: Purple (struggling)
            const Color(0xFFD81B60), // 3-4: Pink (low)
            const Color(0xFFFF6F00), // 5-6: Orange (okay)
            const Color(0xFFFFA726), // 7-8: Light Orange (good)
            const Color(0xFFFFD54F), // 9-10: Yellow (excellent)
          ],
        );
      case ColorGradientOption.pink:
        return GradientColors(
          name: 'Cherry Blossom',
          primary: const Color(0xFFE91E63),
          secondary: const Color(0xFFAB47BC),
          moodGradient: [
            const Color(0xFF6A1B9A), // 1-2: Deep Purple (struggling)
            const Color(0xFF8E24AA), // 3-4: Purple (low)
            const Color(0xFFAB47BC), // 5-6: Light Purple (okay)
            const Color(0xFFEC407A), // 7-8: Pink (good)
            const Color(0xFFF48FB1), // 9-10: Light Pink (excellent)
          ],
        );
    }
  }
}

/// Get mood color from gradient based on rating (1-10)
Color getMoodColorFromRating(int rating, List<Color> gradient) {
  rating = rating.clamp(1, 10);

  if (rating <= 2) return gradient[0];
  if (rating <= 4) return gradient[1];
  if (rating <= 6) return gradient[2];
  if (rating <= 8) return gradient[3];
  return gradient[4];
}

/// Get interpolated mood color for precise rating (supports decimals)
Color getMoodColorInterpolated(double rating, List<Color> gradient) {
  rating = rating.clamp(1.0, 10.0);

  final normalized = (rating - 1.0) / 9.0;
  final position = normalized * (gradient.length - 1);
  final index = position.floor();
  final nextIndex = (index + 1).clamp(0, gradient.length - 1);
  final t = position - index;

  return Color.lerp(gradient[index], gradient[nextIndex], t)!;
}

/// Container for gradient color scheme
class GradientColors {
  final String name;
  final Color primary;
  final Color secondary;
  final List<Color> moodGradient;

  GradientColors({
    required this.name,
    required this.primary,
    required this.secondary,
    required this.moodGradient,
  });
}