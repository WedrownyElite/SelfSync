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
          name: 'Purple Bliss',
          primary: const Color(0xFF6C63FF),
          secondary: const Color(0xFFFF6B9D),
          moodGradient: [
            const Color(0xFFFF6B9D), // Bad (Pink)
            const Color(0xFFFF8A80), // Getting better
            const Color(0xFFFFC107), // Okay (Amber)
            const Color(0xFF8BC34A), // Good (Light Green)
            const Color(0xFF6C63FF), // Excellent (Purple)
          ],
        );
      case ColorGradientOption.blue:
        return GradientColors(
          name: 'Ocean Wave',
          primary: const Color(0xFF2196F3),
          secondary: const Color(0xFF00BCD4),
          moodGradient: [
            const Color(0xFFE91E63), // Bad (Pink)
            const Color(0xFFFF6F00), // Getting better (Orange)
            const Color(0xFFFFC107), // Okay (Amber)
            const Color(0xFF00BCD4), // Good (Cyan)
            const Color(0xFF2196F3), // Excellent (Blue)
          ],
        );
      case ColorGradientOption.teal:
        return GradientColors(
          name: 'Forest Calm',
          primary: const Color(0xFF009688),
          secondary: const Color(0xFF4CAF50),
          moodGradient: [
            const Color(0xFFE53935), // Bad (Red)
            const Color(0xFFFF6F00), // Getting better (Orange)
            const Color(0xFFFDD835), // Okay (Yellow)
            const Color(0xFF4CAF50), // Good (Green)
            const Color(0xFF009688), // Excellent (Teal)
          ],
        );
      case ColorGradientOption.orange:
        return GradientColors(
          name: 'Sunset Glow',
          primary: const Color(0xFFFF5722),
          secondary: const Color(0xFFFFB300),
          moodGradient: [
            const Color(0xFFD32F2F), // Bad (Dark Red)
            const Color(0xFFFF5722), // Getting better (Orange)
            const Color(0xFFFFB300), // Okay (Amber)
            const Color(0xFFFFD54F), // Good (Light Yellow)
            const Color(0xFFFFF176), // Excellent (Bright Yellow)
          ],
        );
      case ColorGradientOption.pink:
        return GradientColors(
          name: 'Cherry Blossom',
          primary: const Color(0xFFE91E63),
          secondary: const Color(0xFFAB47BC),
          moodGradient: [
            const Color(0xFFC62828), // Bad (Dark Red)
            const Color(0xFFE91E63), // Getting better (Pink)
            const Color(0xFFEC407A), // Okay (Light Pink)
            const Color(0xFFAB47BC), // Good (Purple)
            const Color(0xFFBA68C8), // Excellent (Light Purple)
          ],
        );
    }
  }
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