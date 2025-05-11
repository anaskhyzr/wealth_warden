import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/providers.dart';
import '../utils/app_theme.dart';
import '../models/transaction.dart';
import 'transaction_screen.dart';
import 'transaction_history_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Delay data loading slightly to allow UI to render first
    Future.microtask(() => _refreshData());
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load data in the background using compute to move work off the main thread
      await compute(_loadDataInBackground, null);
      
      if (!mounted) return;
      
      // Update providers in sequence to avoid concurrent database access
      if (mounted) {
        final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
        await categoryProvider.loadCategories();
        
        if (mounted) {
          final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
          // Set loading state in the provider
          transactionProvider.setLoading(true);
          
          // Load transactions in a separate microtask
          Future.microtask(() async {
            try {
              await transactionProvider.loadTransactions();
            } catch (e) {
              debugPrint('Error loading transactions: $e');
            } finally {
              if (mounted) {
                transactionProvider.setLoading(false);
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error refreshing dashboard data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // This function runs in a background isolate
  static Future<void> _loadDataInBackground(_) async {
    // Simulate work that would be done in the background
    await Future.delayed(const Duration(milliseconds: 50));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: AppColors.primaryGreen,
          child: _isLoading && Provider.of<TransactionProvider>(context, listen: false).transactions.isEmpty
              ? _buildLoadingIndicator()
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        // Use RepaintBoundary for widgets that don't need to be repainted when other parts change
                        RepaintBoundary(child: _buildHeader()),
                        const SizedBox(height: 24),
                        // Wrap wallet card in RepaintBoundary for better performance
                        RepaintBoundary(child: _buildWalletCard()),
                        const SizedBox(height: 24),
                        // Wrap income/expense cards in RepaintBoundary
                        RepaintBoundary(child: _buildIncomeExpenseCards()),
                        const SizedBox(height: 24),
                        // Wrap transaction header in RepaintBoundary
                        RepaintBoundary(child: _buildRecentTransactionsHeader()),
                        const SizedBox(height: 8),
                        // Wrap transactions in RepaintBoundary
                        RepaintBoundary(child: _buildRecentTransactions()),
                        // Monthly spending section removed
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
        ),
      ),
      // Floating action button removed as transactions can be added from cards on home screen
    );
  }
  
  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading your financial data...'),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'My Wallet',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        // Bell icon removed
      ],
    );
  }

  Widget _buildWalletCard() {
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    
    final balance = transactionProvider.getBalance();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.roundedBoxDecoration(
        color: AppColors.darkCard,
        radius: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Balance',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.darkTextSecondary,
                ),
              ),
              Icon(
                Icons.account_balance_wallet,
                color: AppColors.primaryGreen,
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$currencySymbol ${balance.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: balance >= 0 ? AppColors.primaryGreen : AppColors.categoryRed,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Updated ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeExpenseCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSimpleActionCard(
            title: 'Income',
            subtitle: 'Tap to add income',
            icon: Icons.arrow_upward,
            color: AppColors.primaryGreen,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AddTransactionScreen(isExpense: false),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSimpleActionCard(
            title: 'Expense',
            subtitle: 'Tap to add expense',
            icon: Icons.arrow_downward,
            color: AppColors.categoryRed,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AddTransactionScreen(isExpense: true),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Simple card for income/expense actions
  Widget _buildSimpleActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.roundedBoxDecoration(
          color: AppColors.darkCard,
          radius: 16,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.darkTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFinancialCard({
    required String title,
    required String amount,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.roundedBoxDecoration(
          color: AppColors.darkCard,
          radius: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.darkTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              amount,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.add_circle_outline,
                  color: color,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactionsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Recent Transactions',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const TransactionHistoryScreen(),
              ),
            );
          },
          child: const Text('View All'),
        ),
      ],
    );
  }

  Widget _buildRecentTransactions() {
    final transactionProvider = Provider.of<TransactionProvider>(context);
    // Get only current month transactions
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final nextMonth = DateTime(now.year, now.month + 1);
    
    final recentTransactions = transactionProvider.transactions
        .where((t) => t.date.isAfter(currentMonth) && t.date.isBefore(nextMonth))
        .toList()
        .take(5)
        .toList();
    
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    
    if (recentTransactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.roundedBoxDecoration(
          color: AppColors.darkCard,
          radius: 16,
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: AppColors.darkTextSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'No recent transactions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.darkTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AddTransactionScreen(isExpense: true),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Transaction'),
              ),
            ],
          ),
        ),
      );
    }
    
    return Container(
      decoration: AppTheme.roundedBoxDecoration(
        color: AppColors.darkCard,
        radius: 16,
      ),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: recentTransactions.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final transaction = recentTransactions[index];
          return _buildTransactionTile(transaction, currencySymbol);
        },
      ),
    );
  }

  // Optimized transaction tile with memoization to reduce rebuilds
  Widget _buildTransactionTile(Transaction transaction, String currencySymbol) {
    final isExpense = transaction.isExpense;
    final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
    final categoryIcon = categoryProvider.getCategoryIcon(transaction.category);
    final categoryColor = categoryProvider.getCategoryColor(transaction.category);
    
    // Optimize ListTile for better performance
    return ListTile(
      visualDensity: VisualDensity.compact, // More compact for better performance
      leading: Container(
        width: 40, // Fixed width to prevent layout shifts
        height: 40, // Fixed height to prevent layout shifts
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: categoryColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          categoryIcon,
          color: categoryColor,
          size: 20, // Smaller icon for better performance
        ),
      ),
      title: Text(
        transaction.description,
        // Limit lines to prevent layout shifts
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14), // Smaller text for better performance
      ),
      subtitle: Text(
        // Pre-format date to avoid doing it during build
        DateFormat.yMMMd().format(transaction.date),
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: Text(
        '${isExpense ? '-' : '+'} $currencySymbol${transaction.amount.toStringAsFixed(2)}',
        style: TextStyle(
          fontSize: 14, // Smaller text for better performance
          fontWeight: FontWeight.bold,
          color: isExpense ? AppColors.categoryRed : AppColors.primaryGreen,
        ),
      ),
      // Use dense to reduce the height of each tile
      dense: true,
      onTap: () {
        // Show bottom sheet with edit and delete options
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (context) => Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit, color: AppColors.primaryGreen),
                  title: const Text('Edit Transaction'),
                  onTap: () {
                    Navigator.pop(context); // Close bottom sheet
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddTransactionScreen(
                          isExpense: isExpense,
                          transaction: transaction,
                        ),
                      ),
                    ).then((_) {
                      // Refresh data when returning from edit screen
                      _refreshData();
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete Transaction'),
                  onTap: () async {
                    Navigator.pop(context); // Close bottom sheet
                    
                    // Show confirmation dialog
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Transaction'),
                        content: const Text('Are you sure you want to delete this transaction?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    ) ?? false;
                    
                    if (confirm && context.mounted) {
                      final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
                      final success = await transactionProvider.deleteTransaction(transaction.id!);
                      
                      if (context.mounted) {
                        if (success) {
                          // Refresh data after successful deletion
                          _refreshData();
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Transaction deleted'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to delete transaction'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('View Details'),
                  onTap: () {
                    Navigator.pop(context); // Close bottom sheet
                    
                    // Show transaction details dialog
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Transaction Details'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow('Description', transaction.description),
                            _buildDetailRow('Amount', '$currencySymbol${transaction.amount.toStringAsFixed(2)}'),
                            _buildDetailRow('Category', transaction.category),
                            _buildDetailRow('Date', DateFormat.yMMMd().format(transaction.date)),
                            _buildDetailRow('Type', isExpense ? 'Expense' : 'Income'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySpendingHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Monthly Spending',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        TextButton(
          onPressed: () {
            // Navigate to detailed spending analytics
          },
          child: const Text('See Details'),
        ),
      ],
    );
  }

  Widget _buildTopCategories() {
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    
    final topCategories = transactionProvider.getTopExpenseCategories(3);
    final totalExpenses = transactionProvider.getMonthlyExpenses();
    
    if (topCategories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.roundedBoxDecoration(
          color: AppColors.darkCard,
          radius: 16,
        ),
        child: Center(
          child: Text(
            'No expense data available',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
        ),
      );
    }
    
    return Container(
      decoration: AppTheme.roundedBoxDecoration(
        color: AppColors.darkCard,
        radius: 16,
      ),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: topCategories.length,
        itemBuilder: (context, index) {
          final category = topCategories[index]['category'] as String;
          final amount = topCategories[index]['amount'] as double;
          final percentage = totalExpenses > 0 
              ? (amount / totalExpenses * 100).toInt() 
              : 0;
          
          final categoryIcon = categoryProvider.getCategoryIcon(category);
          final categoryColor = categoryProvider.getCategoryColor(category);
          
          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                categoryIcon,
                color: categoryColor,
              ),
            ),
            title: Text(
              category,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$currencySymbol${amount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                Text(
                  '$percentage%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
