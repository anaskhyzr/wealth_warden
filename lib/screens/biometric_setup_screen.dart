import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../utils/app_theme.dart';
import 'pin_setup_screen.dart';
import 'main_screen.dart';

class BiometricSetupScreen extends StatefulWidget {
  final bool isFirstTimeSetup;
  
  const BiometricSetupScreen({
    super.key,
    this.isFirstTimeSetup = true,
  });

  @override
  State<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends State<BiometricSetupScreen> {
  bool _isLoading = false;
  bool _biometricAvailable = false;
  
  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }
  
  Future<void> _checkBiometricAvailability() async {
    setState(() => _isLoading = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.initAuth();
      
      setState(() {
        _biometricAvailable = authProvider.isBiometricAvailable;
      });
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _enableBiometric() async {
    setState(() => _isLoading = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.enableBiometric();
      
      if (!mounted) return;
      
      if (success) {
        if (widget.isFirstTimeSetup) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        } else {
          Navigator.of(context).pop(true);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to enable biometric authentication')),
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
  
  void _skipBiometric() {
    if (widget.isFirstTimeSetup) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    } else {
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biometric Authentication'),
        automaticallyImplyLeading: !widget.isFirstTimeSetup,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.darkCard,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.fingerprint,
                        size: 80,
                        color: _biometricAvailable
                            ? AppColors.primaryGreen
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      _biometricAvailable
                          ? 'Enable Biometric Authentication'
                          : 'Biometric Authentication Not Available',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _biometricAvailable
                          ? 'Use your fingerprint or face ID to quickly and securely access your financial data without entering your PIN.'
                          : 'Your device does not support biometric authentication or it has not been set up in your device settings.',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.darkTextSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(),
                    if (_biometricAvailable)
                      ElevatedButton(
                        onPressed: _enableBiometric,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Enable Biometric Authentication',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _skipBiometric,
                      child: Text(
                        _biometricAvailable ? 'Skip for now' : 'Continue',
                        style: TextStyle(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}
