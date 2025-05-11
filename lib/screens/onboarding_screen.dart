import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/providers.dart';
import '../utils/app_theme.dart';
import 'pin_setup_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 5;
  bool _isLoading = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  
  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'Welcome to WealthWarden',
      'description': 'Your personal finance manager that helps you track expenses, set budgets, and achieve your financial goals.',
      'image': 'assets/images/onboarding_1.png',
      'icon': Icons.account_balance_wallet,
    },
    {
      'title': 'Track Your Expenses',
      'description': 'Easily record and categorize your income and expenses. View detailed reports and analyze your spending habits.',
      'image': 'assets/images/onboarding_2.png',
      'icon': Icons.receipt_long,
    },
    {
      'title': 'Secure Your Data',
      'description': 'Your financial data is protected with PIN and biometric authentication. Backup to Google Drive for extra safety.',
      'image': 'assets/images/onboarding_4.png',
      'icon': Icons.security,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  _buildWelcomePage(),
                  _buildFeaturePage(
                    title: 'Track Your Finances',
                    description: 'Easily record your income and expenses with just a few taps. Categorize transactions to understand where your money goes.',
                    icon: Icons.account_balance_wallet,
                    imagePath: 'assets/onboarding_track.png',
                  ),
                  _buildFeaturePage(
                    title: 'Secure Your Data',
                    description: 'Your financial data is protected with PIN and biometric authentication. Back up to Google Drive for extra safety.',
                    icon: Icons.security,
                    imagePath: 'assets/onboarding_security.png',
                  ),
                  _buildFeaturePage(
                    title: 'Visualize Your Spending',
                    description: 'View detailed charts and reports to understand your spending patterns and make better financial decisions.',
                    icon: Icons.pie_chart,
                    imagePath: 'assets/onboarding_reports.png',
                  ),
                ],
              ),
            ),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Container(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
              Icons.account_balance_wallet,
              size: 60,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'Welcome to\nWealthWarden',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.darkTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            'Your personal finance companion for tracking expenses, managing budgets, and achieving your financial goals.',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.darkTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePage({
    required String title,
    required String description,
    required IconData icon,
    String? imagePath,
  }) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              size: 40,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.darkTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.darkTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (imagePath != null)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Icon(
                    icon,
                    size: 100,
                    color: AppColors.primaryGreen.withOpacity(0.2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _totalPages,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                width: _currentPage == index ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: _currentPage == index
                      ? AppColors.primaryGreen
                      : AppColors.darkTextSecondary.withOpacity(0.3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              if (_currentPage > 0)
                Expanded(
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.darkTextSecondary,
                    ),
                    child: const Text('Previous'),
                  ),
                )
              else
                Expanded(
                  child: TextButton(
                    onPressed: _isLoading ? null : () => _completeOnboarding(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.darkTextSecondary,
                    ),
                    child: const Text('Skip'),
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          if (_currentPage < _totalPages - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            _completeOnboarding();
                          }
                        },
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
                      : Text(
                          _currentPage < _totalPages - 1 ? 'Next' : 'Get Started',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Future<void> _completeOnboarding() async {
    setState(() => _isLoading = true);
    
    try {
      // Initialize providers if needed
      await Provider.of<TransactionProvider>(context, listen: false).loadTransactions();
      await Provider.of<CategoryProvider>(context, listen: false).loadCategories();
      
      // Mark onboarding as complete
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);
      
      if (!mounted) return;
      
      // Navigate to PIN setup
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const PinSetupScreen()),
      );
    } catch (e) {
      debugPrint('Error completing onboarding: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
        setState(() => _isLoading = false);
      }
    }
  }
}
