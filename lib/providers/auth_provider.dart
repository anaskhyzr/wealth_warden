import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';

class AuthProvider with ChangeNotifier {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isAuthenticated = false;
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  bool get isBiometricAvailable => _isBiometricAvailable;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Initialize authentication state
  Future<void> initAuth() async {
    _setLoading(true);
    
    try {
      // Check if biometric authentication is available
      _isBiometricAvailable = await _localAuth.canCheckBiometrics &&
                              await _localAuth.isDeviceSupported();
      
      // Check if biometric authentication is enabled
      final prefs = await SharedPreferences.getInstance();
      _isBiometricEnabled = prefs.getBool('biometric_enabled') ?? false;
      
      notifyListeners();
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

  // Verify PIN
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
        notifyListeners();
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

  // Enable/disable biometric authentication
  Future<bool> toggleBiometric(bool enable) async {
    _setLoading(true);
    _clearError();
    
    try {
      if (enable && !_isBiometricAvailable) {
        _setError('Biometric authentication is not available on this device');
        return false;
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', enable);
      
      _isBiometricEnabled = enable;
      notifyListeners();
      
      return true;
    } catch (e) {
      _setError('Failed to toggle biometric: ${e.toString()}');
      debugPrint('Error toggling biometric: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Enable biometric authentication (alias for toggleBiometric(true))
  Future<bool> enableBiometric() async {
    return toggleBiometric(true);
  }

  // Authenticate with biometrics
  Future<bool> authenticateWithBiometrics() async {
    _setLoading(true);
    _clearError();
    
    try {
      if (!_isBiometricAvailable || !_isBiometricEnabled) {
        _setError('Biometric authentication is not available or not enabled');
        return false;
      }
      
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access WealthWarden',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      
      if (authenticated) {
        _isAuthenticated = true;
        notifyListeners();
      }
      
      return authenticated;
    } catch (e) {
      _setError('Failed to authenticate with biometrics: ${e.toString()}');
      debugPrint('Error authenticating with biometrics: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Sign out
  void signOut() {
    _isAuthenticated = false;
    notifyListeners();
  }

  // Helper methods
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}
