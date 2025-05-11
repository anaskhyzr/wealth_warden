import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import '../main.dart';
import '../providers/providers.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _pin = '';
  bool _isLoading = false;
  bool _isBiometricAuthInProgress = false;
  final List<bool> _dotAnimations = List.generate(4, (_) => false);
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  Future<void> _initAuth() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.initAuth();
    
    // Check if biometric authentication is available and enabled
    if (authProvider.isBiometricAvailable && authProvider.isBiometricEnabled) {
      // Slight delay to ensure UI is fully rendered before showing biometric prompt
      Future.delayed(const Duration(milliseconds: 500), () {
        _authenticateWithBiometrics();
      });
    }
  }

  Future<void> _verifyPIN() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.verifyPin(_pin);
      
      if (success) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      } else {
        if (!mounted) return;
        setState(() => _pin = '');
        
        // Show error message
        final errorMessage = authProvider.errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage ?? 'Invalid PIN')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _pin = '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _authenticateWithBiometrics() async {
    if (_isBiometricAuthInProgress) return;
    
    setState(() => _isBiometricAuthInProgress = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.authenticateWithBiometrics();
      
      if (success) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
    } finally {
      if (mounted) {
        setState(() => _isBiometricAuthInProgress = false);
      }
    }
  }

  Future<void> _addDigit(String digit) async {
    if (_isLoading || _pin.length >= 4) return;

    setState(() {
      _pin += digit;
      _animateDot(_pin.length - 1);
    });

    if (_pin.length == 4) {
      await _verifyPIN();
    }
  }

  Future<void> _removeDigit() async {
    if (_pin.isEmpty || _isLoading) return;

    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  void _animateDot(int index) {
    setState(() => _dotAnimations[index] = true);
    Future.delayed(const Duration(milliseconds: 0), () {
      if (mounted) {
        setState(() => _dotAnimations[index] = false);
      }
    });
  }

  Widget _buildPinDot(bool filled, bool animated) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 10),
      margin: const EdgeInsets.symmetric(horizontal: 6), // Reduced margin
      width: animated ? 12 : 10, // Smaller dots
      height: animated ? 12 : 10, // Smaller dots
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface.withOpacity(0.2),
      ),
    );
  }

  Widget _buildNumberButton(String number) {
    final theme = Theme.of(context);
    return TextButton(
      onPressed: _isLoading ? null : () => _addDigit(number),
      style: TextButton.styleFrom(
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(24),
        foregroundColor: _isLoading
            ? theme.colorScheme.onSurface.withOpacity(0.3)
            : theme.colorScheme.onSurface,
      ),
      child: Text(
        number,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: _isLoading
              ? theme.colorScheme.onSurface.withOpacity(0.3)
              : theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 30), // Reduced top padding
              child: const SizedBox(height: 30), // Smaller spacer
            ),
            Text(
              'Enter your login PIN',
              style: TextStyle(
                fontSize: 28, // Smaller font size
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 30), // Reduced spacing
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (index) => _buildPinDot(
                  index < _pin.length,
                  _dotAnimations[index],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20), // Reduced top padding
              child: const SizedBox(height: 10), // Smaller spacer
            ),
            Text(
              'Forgetting your PIN can lead to data loss.',
              style: TextStyle(
                fontSize: 13, // Smaller font size
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12), // Reduced spacing
            // Biometric authentication button
            if (authProvider.isBiometricAvailable && authProvider.isBiometricEnabled)
              TextButton.icon(
                onPressed: _isBiometricAuthInProgress || _isLoading ? null : _authenticateWithBiometrics,
                icon: Icon(
                  Icons.fingerprint,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                label: Text(
                  'Use Biometrics',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const Spacer(),
            // PIN pad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                childAspectRatio: 1.2, // Increased aspect ratio to make buttons shorter
                mainAxisSpacing: 8, // Reduced spacing between rows
                crossAxisSpacing: 8, // Added spacing between columns
                children: [
                  ...List.generate(9, (index) => _buildNumberButton('${index + 1}')),
                  const SizedBox(),
                  _buildNumberButton('0'),
                  IconButton(
                    onPressed: _isLoading ? null : _removeDigit,
                    icon: Icon(
                      Icons.backspace_outlined,
                      color: _isLoading
                          ? theme.colorScheme.onSurface.withOpacity(0.3)
                          : theme.colorScheme.onSurface,
                    ),
                    iconSize: 28, // Slightly smaller icon
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16), // Reduced bottom padding
            // Loading indicator
            if (_isLoading || _isBiometricAuthInProgress)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}