import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'login_screen.dart';
import '../providers/providers.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _isLoading = false;
  final List<bool> _dotAnimations = List.generate(4, (_) => false);

  Future<void> _setupPIN() async {
    if (_pin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN must be 4 digits')),
      );
      return;
    }

    if (_pin != _confirmPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PINs do not match. Please try again.')),
      );
      setState(() {
        _pin = '';
        _confirmPin = '';
        _isConfirming = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.setupPin(_pin);

      if (!mounted) return;

      if (success) {
        // Biometric authentication removed, go directly to login screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to set up PIN. Please try again.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addDigit(String digit) async {
    if (_isLoading) return;
    
    setState(() {
      if (!_isConfirming) {
        if (_pin.length < 4) {
          _pin += digit;
          _animateDot(_pin.length - 1);
          if (_pin.length == 4) {
            _isConfirming = true;
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) {
                setState(() {});
              }
            });
          }
        }
      } else {
        if (_confirmPin.length < 4) {
          _confirmPin += digit;
          _animateDot(_confirmPin.length - 1);
          if (_confirmPin.length == 4) {
            _setupPIN();
          }
        }
      }
    });
  }

  Future<void> _removeDigit() async {
    if (_isLoading || (_isConfirming && _confirmPin.isEmpty) || (!_isConfirming && _pin.isEmpty)) return;

    setState(() {
      if (_isConfirming) {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      } else {
        _pin = _pin.substring(0, _pin.length - 1);
      }
    });
  }

  void _animateDot(int index) {
    setState(() => _dotAnimations[index] = true);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() => _dotAnimations[index] = false);
      }
    });
  }

  Widget _buildPinDot(bool filled, bool animated) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 0),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: animated ? 14 : 12,
      height: animated ? 14 : 12,
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

  Future<bool> _showBiometricPrompt() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Biometric Authentication'),
        content: const Text(
          'Would you like to enable fingerprint or face authentication for faster login?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not Now'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Enable'),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 50),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Text(
                'Create PIN',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _isConfirming ? 'Confirm your PIN' : 'Enter a 4-digit PIN',
                style: TextStyle(
                  fontSize: 20,
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (index) => _buildPinDot(
                    _isConfirming
                        ? index < _confirmPin.length
                        : index < _pin.length,
                    _dotAnimations[index],
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  childAspectRatio: 1,
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
                      iconSize: 26,
                    ),
                  ],
                ),
              ),
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: CircularProgressIndicator(),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}