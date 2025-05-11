import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../utils/app_theme.dart';
import 'dashboard_screen.dart';
import 'transaction_history_screen.dart';
import 'settings_screen.dart';
import 'enhanced_stats_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isInitialLoad = true;
  late AnimationController _loadingAnimationController;
  
  // Using IndexedStack to preserve state and improve performance
  late final List<Widget> _screens = [
    const DashboardScreen(),
    const StatsScreen(),
    const SettingsScreen(),
  ];
  
  @override
  bool get wantKeepAlive => true; // Keep state alive when switching tabs
  
  final List<String> _titles = [
    'Dashboard',
    'Stats',
    'Settings',
  ];
  
  @override
  void initState() {
    super.initState();
    
    // Initialize loading animation controller
    _loadingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    // Load data with a slight delay to allow UI to render first
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }
  
  @override
  void dispose() {
    _loadingAnimationController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // First stage: Load only essential data for UI rendering
      // This makes the initial screen appear faster
      final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
      await categoryProvider.loadCategories();
      
      // Second stage: Load transactions with a slight delay to allow UI to render first
      if (mounted) {
        // Mark initial load as complete to show the UI
        setState(() {
          _isInitialLoad = false;
        });
        
        // Use a slight delay before loading transactions
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (mounted) {
          final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
          transactionProvider.setLoading(true);
          
          // Load transactions in a separate isolate
          Future.microtask(() async {
            try {
              await transactionProvider.loadTransactions();
            } catch (e) {
              debugPrint('Error loading transactions: $e');
            } finally {
              if (mounted) {
                transactionProvider.setLoading(false);
                setState(() {
                  _isLoading = false;
                });
              }
            }
          });
        }
        
        // Third stage: Load recurring transactions and other non-critical data
        Future.delayed(const Duration(milliseconds: 500), () async {
          if (!mounted) return;
          try {
            final recurringProvider = Provider.of<RecurringTransactionProvider>(context, listen: false);
            await recurringProvider.loadRecurringTransactions();
          } catch (e) {
            debugPrint('Error loading recurring transactions: $e');
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialLoad = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: ${e.toString()}')),
        );
      }
    }
  }
  
  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Use a rotating animation for the loading indicator
          RotationTransition(
            turns: _loadingAnimationController,
            child: Container(
              width: 60,
              height: 60,
              padding: const EdgeInsets.all(8.0),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading your financial data...',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.darkTextPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This may take a moment',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.darkTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    return Scaffold(
      // Show loading indicator during initial app load
      body: _isInitialLoad && _isLoading
          ? _buildLoadingIndicator()
          : IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
      bottomNavigationBar: Container(
        // Optimize the shadow to be less resource-intensive
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        // Use RepaintBoundary to prevent unnecessary repaints
        child: RepaintBoundary(
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              if (_currentIndex != index) { // Only setState if actually changing tabs
                setState(() {
                  _currentIndex = index;
                });
              }
            },
            backgroundColor: AppColors.darkBackground,
            selectedItemColor: AppColors.primaryGreen, // Use fixed color instead of dynamic primary color
            unselectedItemColor: AppColors.darkTextSecondary,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            // Optimize by using const where possible
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_outlined),
                activeIcon: Icon(Icons.bar_chart),
                label: 'Stats',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showAddTransactionOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add Transaction',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildOptionButton(
                    context,
                    icon: Icons.arrow_upward,
                    label: 'Income',
                    color: AppColors.incomeGreen,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(
                        context,
                        '/add_transaction',
                        arguments: {'isExpense': false},
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildOptionButton(
                    context,
                    icon: Icons.arrow_downward,
                    label: 'Expense',
                    color: AppColors.expenseRed,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(
                        context,
                        '/add_transaction',
                        arguments: {'isExpense': true},
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildOptionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
