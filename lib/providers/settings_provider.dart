import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  // Theme settings
  ThemeMode _themeMode = ThemeMode.system;
  Color _primaryColor = const Color(0xFF1ED760); // Default green
  
  // Currency settings
  String _currencySymbol = 'Rs';
  String _currencyCode = 'INR';
  
  // Other settings
  bool _showBalance = true;
  String _dateFormat = 'MMM d, yyyy';
  
  // Loading and error states
  bool _isLoading = false;
  String? _errorMessage;

  // Available primary colors
  static const Map<String, Color> availableColors = {
    'green': Color(0xFF1ED760),
    'blue': Color(0xFF3498DB),
    'red': Color(0xFFE74C3C),
    'purple': Color(0xFF9B59B6),
    'pink': Color(0xFFE91E63),
  };

  // Getters
  ThemeMode get themeMode => _themeMode;
  Color get primaryColor => _primaryColor;
  String get currencySymbol => _currencySymbol;
  String get currencyCode => _currencyCode;
  bool get showBalance => _showBalance;
  String get dateFormat => _dateFormat;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Initialize settings with microtask to avoid setState during build
  Future<void> loadSettings() async {
    _setLoading(true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load theme settings
      final themeModeIndex = prefs.getInt('theme_mode') ?? 0;
      _themeMode = ThemeMode.values[themeModeIndex];
      
      // Primary color feature removed, but keep default for compatibility
      _primaryColor = availableColors['green']!;
      
      // Load currency settings
      _currencySymbol = prefs.getString('currency_symbol') ?? 'Rs';
      _currencyCode = prefs.getString('currency_code') ?? 'INR';
      
      // Load other settings
      _showBalance = prefs.getBool('show_balance') ?? true;
      _dateFormat = prefs.getString('date_format') ?? 'MMM d, yyyy';
      
      // Use microtask to avoid setState during build
      Future.microtask(() {
        notifyListeners();
      });
    } catch (e) {
      _setError('Failed to load settings: ${e.toString()}');
      debugPrint('Error loading settings: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Update theme mode with microtask to avoid setState during build
  Future<void> setThemeMode(ThemeMode mode) async {
    _setLoading(true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('theme_mode', mode.index);
      
      _themeMode = mode;
      
      // Use microtask to avoid setState during build
      Future.microtask(() {
        notifyListeners();
      });
    } catch (e) {
      _setError('Failed to update theme: ${e.toString()}');
      debugPrint('Error updating theme: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Update currency with microtask to avoid setState during build
  Future<void> setCurrency(String symbol, String code) async {
    _setLoading(true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currency_symbol', symbol);
      await prefs.setString('currency_code', code);
      
      _currencySymbol = symbol;
      _currencyCode = code;
      
      // Use microtask to avoid setState during build
      Future.microtask(() {
        notifyListeners();
      });
    } catch (e) {
      _setError('Failed to update currency: ${e.toString()}');
      debugPrint('Error updating currency: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Toggle show balance with microtask to avoid setState during build
  Future<void> toggleShowBalance() async {
    _setLoading(true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('show_balance', !_showBalance);
      
      _showBalance = !_showBalance;
      
      // Use microtask to avoid setState during build
      Future.microtask(() {
        notifyListeners();
      });
    } catch (e) {
      _setError('Failed to update show balance: ${e.toString()}');
      debugPrint('Error updating show balance: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Update date format with microtask to avoid setState during build
  Future<void> setDateFormat(String format) async {
    _setLoading(true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('date_format', format);
      
      _dateFormat = format;
      
      // Use microtask to avoid setState during build
      Future.microtask(() {
        notifyListeners();
      });
    } catch (e) {
      _setError('Failed to update date format: ${e.toString()}');
      debugPrint('Error updating date format: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Primary color update method removed as feature is no longer needed
  }

  // Reset all settings to default
  Future<void> resetSettings() async {
    _setLoading(true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear all settings
      await prefs.clear();
      
      // Reset to defaults
      _themeMode = ThemeMode.system;
      _primaryColor = availableColors['green']!;
      _currencySymbol = 'Rs';
      _currencyCode = 'INR';
      _showBalance = true;
      _dateFormat = 'MMM d, yyyy';
      
      // Use microtask to avoid setState during build
      Future.microtask(() {
        notifyListeners();
      });
    } catch (e) {
      _setError('Failed to reset settings: ${e.toString()}');
      debugPrint('Error resetting settings: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Helper methods
  // Use microtask for state updates to avoid setState during build
  void _setLoading(bool loading) {
    _isLoading = loading;
    // Only notify if the value changed
    if (loading != _isLoading) {
      Future.microtask(() {
        notifyListeners();
      });
    }
  }

  void _setError(String message) {
    _errorMessage = message;
    // Use microtask to avoid setState during build
    Future.microtask(() {
      notifyListeners();
    });
  }

  void _clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
    }
  }
}
