import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Initialize authentication state - biometric authentication removed
  Future<void> initAuth() async {
    _setLoading(true);
    
    try {
      // Simplified initialization without biometrics
      // Use microtask to avoid setState during build
      Future.microtask(() {
        notifyListeners();
      });
    } catch (e) {
      _setError('Failed to initialize authentication: ${e.toString()}');
      debugPrint('Error initializing authentication: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Check if PIN is set
  Future<bool> isPinSet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hashedPin = prefs.getString('pin');
      return hashedPin != null;
    } catch (e) {
      _setError('Failed to check PIN: ${e.toString()}');
      debugPrint('Error checking PIN: $e');
      return false;
    }
  }

  // Set up PIN
  Future<bool> setupPin(String pin) async {
    _setLoading(true);
    _clearError();
    
    try {
      if (pin.length < 4) {
        _setError('PIN must be at least 4 digits');
        return false;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final hashedPin = _hashPin(pin);
      await prefs.setString('pin', hashedPin);
      
      return true;
    } catch (e) {
      _setError('Failed to set up PIN: ${e.toString()}');
      debugPrint('Error setting up PIN: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Verify PIN with microtask to avoid setState during build
  Future<bool> verifyPin(String pin) async {
    _setLoading(true);
    _clearError();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedHashedPin = prefs.getString('pin');
      
      if (storedHashedPin == null) {
        _setError('PIN not set');
        return false;
      }
      
      final hashedInputPin = _hashPin(pin);
      final isValid = storedHashedPin == hashedInputPin;
      
      if (isValid) {
        _isAuthenticated = true;
        // Use microtask to avoid setState during build
        Future.microtask(() {
          notifyListeners();
        });
      } else {
        _setError('Invalid PIN');
      }
      
      return isValid;
    } catch (e) {
      _setError('Failed to verify PIN: ${e.toString()}');
      debugPrint('Error verifying PIN: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Change PIN
  Future<bool> changePin(String currentPin, String newPin) async {
    _setLoading(true);
    _clearError();
    
    try {
      // Verify current PIN first
      final isValid = await verifyPin(currentPin);
      
      if (!isValid) {
        return false;
      }
      
      if (newPin.length < 4) {
        _setError('New PIN must be at least 4 digits');
        return false;
      }
      
      // Set new PIN
      return await setupPin(newPin);
    } catch (e) {
      _setError('Failed to change PIN: ${e.toString()}');
      debugPrint('Error changing PIN: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Sign out with microtask to avoid setState during build
  void signOut() {
    _isAuthenticated = false;
    // Use microtask to avoid setState during build
    Future.microtask(() {
      notifyListeners();
    });
  }

  // Helper methods
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Use microtask for state updates to avoid setState during build
  void _setLoading(bool loading) {
    _isLoading = loading;
    // Use microtask to avoid setState during build
    Future.microtask(() {
      notifyListeners();
    });
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
