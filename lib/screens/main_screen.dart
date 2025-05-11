import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../utils/app_theme.dart';
import 'dashboard_screen.dart';
import 'transaction_history_screen.dart';
// Budget screen removed from navbar
import 'settings_screen.dart';
import 'enhanced_stats_screen.dart';
import 'categories_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with AutomaticKeepAliveClientMixin {
  int _currentIndex = 0;
  
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
    _loadData();
  }
  
  Future<void> _loadData() async {
    try {
      // Use a more efficient loading strategy with prioritization
      final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
      
      // First load categories only as they're needed immediately
      await categoryProvider.loadCategories();
      
      // Then load transactions in the background
      if (mounted) {
        Future.microtask(() async {
          try {
            final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
            await transactionProvider.loadTransactions();
          } catch (e) {
            debugPrint('Error loading transactions: $e');
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: ${e.toString()}')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    // Primary color feature removed
    
    return Scaffold(
      // Use IndexedStack to preserve state of each tab
      body: IndexedStack(
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
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart),
                label: 'Stats',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
      // Removed floating action button since we no longer have the transactions tab
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
