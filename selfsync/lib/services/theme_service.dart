import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing app theme preferences
class ThemeService extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _colorGradientKey = 'color_gradient';

  ThemeMode _themeMode = ThemeMode.system;
  ColorGradientOption _selectedGradient = ColorGradientOption.purpleBlue;

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
        orElse: () => ColorGradientOption.purpleBlue,
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
  purpleBlue,
  sunsetOrange,
  oceanTeal,
  forestGreen,
  rosePink,
  goldenAmber,
  arcticBlue, 
  lavenderMist,
}

extension ColorGradientExtension on ColorGradientOption {
  GradientColors get colors {
    switch (this) {
      case ColorGradientOption.purpleBlue:
        return GradientColors(
          name: 'Purple Dream',
          primary: const Color(0xFF667EEA),
          secondary: const Color(0xFF764BA2),
          moodGradient: [
            const Color(0xFF4A148C), // 1-2: Deep Purple (struggling)
            const Color(0xFF6A1B9A), // 3-4: Purple (low)
            const Color(0xFF9575CD), // 5-6: Lavender (okay)
            const Color(0xFF7E57C2), // 7-8: Medium Purple (good)
            const Color(0xFF667EEA), // 9-10: Bright Purple-Blue (excellent)
          ],
        );
      case ColorGradientOption.sunsetOrange:
        return GradientColors(
          name: 'Sunset Glow',
          primary: const Color(0xFFFF5E3A),
          secondary: const Color(0xFFFF9068),
          moodGradient: [
            const Color(0xFF8E24AA), // 1-2: Purple (struggling)
            const Color(0xFFD81B60), // 3-4: Pink (low)
            const Color(0xFFFF6F00), // 5-6: Deep Orange (okay)
            const Color(0xFFFFA726), // 7-8: Orange (good)
            const Color(0xFFFFD54F), // 9-10: Yellow (excellent)
          ],
        );
      case ColorGradientOption.oceanTeal:
        return GradientColors(
          name: 'Ocean Breeze',
          primary: const Color(0xFF00BCD4),
          secondary: const Color(0xFF26C6DA),
          moodGradient: [
            const Color(0xFF1565C0), // 1-2: Deep Blue (struggling)
            const Color(0xFF1976D2), // 3-4: Blue (low)
            const Color(0xFF42A5F5), // 5-6: Light Blue (okay)
            const Color(0xFF26C6DA), // 7-8: Cyan (good)
            const Color(0xFF4DD0E1), // 9-10: Light Cyan (excellent)
          ],
        );
      case ColorGradientOption.forestGreen:
        return GradientColors(
          name: 'Forest Calm',
          primary: const Color(0xFF43A047),
          secondary: const Color(0xFF66BB6A),
          moodGradient: [
            const Color(0xFF5D4037), // 1-2: Brown (struggling)
            const Color(0xFF795548), // 3-4: Light Brown (low)
            const Color(0xFF9CCC65), // 5-6: Light Green (okay)
            const Color(0xFF66BB6A), // 7-8: Green (good)
            const Color(0xFF43A047), // 9-10: Deep Green (excellent)
          ],
        );
      case ColorGradientOption.rosePink:
        return GradientColors(
          name: 'Rose Garden',
          primary: const Color(0xFFEC407A),
          secondary: const Color(0xFFF48FB1),
          moodGradient: [
            const Color(0xFF6A1B9A), // 1-2: Deep Purple (struggling)
            const Color(0xFF8E24AA), // 3-4: Purple (low)
            const Color(0xFFAB47BC), // 5-6: Light Purple (okay)
            const Color(0xFFEC407A), // 7-8: Pink (good)
            const Color(0xFFF48FB1), // 9-10: Light Pink (excellent)
          ],
        );
      case ColorGradientOption.goldenAmber:
        return GradientColors(
          name: 'Golden Hour',
          primary: const Color(0xFFFF8F00),
          secondary: const Color(0xFFFFB300),
          moodGradient: [
            const Color(0xFFE64A19), // 1-2: Deep Orange-Red (struggling)
            const Color(0xFFFF6F00), // 3-4: Orange (low)
            const Color(0xFFFFA726), // 5-6: Light Orange (okay)
            const Color(0xFFFFB300), // 7-8: Amber (good)
            const Color(0xFFFFD54F), // 9-10: Yellow (excellent)
          ],
        );
      case ColorGradientOption.arcticBlue:
        return GradientColors(
          name: 'Arctic Frost',
          primary: const Color(0xFF4FC3F7),
          secondary: const Color(0xFF81D4FA),
          moodGradient: [
            const Color(0xFF0D47A1), // 1-2: Navy (struggling)
            const Color(0xFF1565C0), // 3-4: Blue (low)
            const Color(0xFF1976D2), // 5-6: Medium Blue (okay)
            const Color(0xFF42A5F5), // 7-8: Light Blue (good)
            const Color(0xFF81D4FA), // 9-10: Sky Blue (excellent)
          ],
        );
      case ColorGradientOption.lavenderMist:
        return GradientColors(
          name: 'Lavender Mist',
          primary: const Color(0xFF9575CD),
          secondary: const Color(0xFFB39DDB),
          moodGradient: [
            const Color(0xFF4A148C), // 1-2: Deep Purple (struggling)
            const Color(0xFF6A1B9A), // 3-4: Purple (low)
            const Color(0xFF8E24AA), // 5-6: Medium Purple (okay)
            const Color(0xFF9575CD), // 7-8: Lavender (good)
            const Color(0xFFB39DDB), // 9-10: Light Lavender (excellent)
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

  List<Color> get gradientColors => [primary, secondary];
}