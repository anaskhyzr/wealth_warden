import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/providers.dart';
import '../utils/app_theme.dart';
import '../models/transaction.dart';
import 'transaction_screen.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> with AutomaticKeepAliveClientMixin {  
  @override
  bool get wantKeepAlive => true; // Keep state alive when switching tabs
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'Income', 'Expense'];

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onPressed: () {
              _showFilterOptions(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chip
          if (_selectedFilter != 'All')
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Wrap(
                spacing: 8.0,
                children: [
                  Chip(
                    label: Text('Type: $_selectedFilter'),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () {
                      setState(() {
                        _selectedFilter = 'All';
                      });
                    },
                  ),
                ],
              ),
            ),
          
          // Transaction list
          Expanded(
            child: _buildTransactionList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddTransactionScreen(isExpense: true),
            ),
          );
        },
        backgroundColor: AppColors.primaryGreen,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter by Type',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8.0,
                children: _filterOptions.map((filter) {
                  return ChoiceChip(
                    label: Text(filter),
                    selected: _selectedFilter == filter,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                        Navigator.pop(context);
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransactionList() {
    return Consumer<TransactionProvider>(
      builder: (context, transactionProvider, child) {
        // Get filtered transactions
        final transactions = _getFilteredTransactions(transactionProvider);
        
        if (transactions.isEmpty) {
          return const Center(
            child: Text('No transactions found'),
          );
        }
        
        // Using ListView.separated for better performance
        return ListView.separated(
          itemCount: transactions.length,
          // Increase cache extent to reduce rebuilds
          cacheExtent: 1000,
          // Use const divider to avoid rebuilding dividers
          separatorBuilder: (context, index) => const Divider(height: 1),
          // Optimize item builder
          itemBuilder: (context, index) {
            // Use const where possible and avoid unnecessary widget creation
            final transaction = transactions[index];
            return _buildTransactionTile(context, transaction);
          },
        );
      },
    );
  }

  List<Transaction> _getFilteredTransactions(TransactionProvider provider) {
    var transactions = provider.transactions;
    
    // Filter by transaction type
    if (_selectedFilter != 'All') {
      final type = _selectedFilter.toLowerCase();
      transactions = transactions.where((t) => t.type.toLowerCase() == type).toList();
    }
    
    // Sort by date (newest first)
    transactions.sort((a, b) => b.date.compareTo(a.date));
    
    return transactions;
  }

  Widget _buildTransactionTile(BuildContext context, Transaction transaction) {
    final isExpense = transaction.type.toLowerCase() == 'expense';
    final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    
    final currencySymbol = settingsProvider.currencySymbol;
    final categoryColor = categoryProvider.getCategoryColor(transaction.category);
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: categoryColor.withOpacity(0.2),
        child: Icon(
          Icons.category,
          color: categoryColor,
        ),
      ),
      title: Text(transaction.description),
      subtitle: Text(
        '${DateFormat('MMM d, yyyy').format(transaction.date)} • ${transaction.category}',
      ),
      trailing: Text(
        '${isExpense ? '-' : '+'} $currencySymbol${transaction.amount.toStringAsFixed(2)}',
        style: TextStyle(
          color: isExpense ? AppColors.expenseRed : AppColors.incomeGreen,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () {
        _showTransactionDetails(context, transaction);
      },
    );
  }

  void _showTransactionDetails(BuildContext context, Transaction transaction) {
    final isExpense = transaction.type.toLowerCase() == 'expense';
    final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    
    final currencySymbol = settingsProvider.currencySymbol;
    final categoryColor = categoryProvider.getCategoryColor(transaction.category);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with amount
              Center(
                child: Text(
                  '$currencySymbol${transaction.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isExpense ? AppColors.expenseRed : AppColors.incomeGreen,
                  ),
                ),
              ),
              Center(
                child: Text(
                  isExpense ? 'Expense' : 'Income',
                  style: TextStyle(
                    color: isExpense ? AppColors.expenseRed : AppColors.incomeGreen,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Transaction details
              _buildDetailRow('Description', transaction.description, Icons.description),
              const SizedBox(height: 16),
              _buildDetailRow('Category', transaction.category, Icons.category),
              const SizedBox(height: 16),
              _buildDetailRow('Date', DateFormat('MMMM d, yyyy').format(transaction.date), Icons.calendar_today),
              
              if (transaction.notes != null && transaction.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildDetailRow('Notes', transaction.notes!, Icons.note),
              ],
              
              const SizedBox(height: 24),
              
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddTransactionScreen(
                            isExpense: isExpense,
                            transaction: transaction,
                          ),
                        ),
                      );
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmDelete(context, transaction);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, Transaction transaction) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Transaction'),
          content: const Text('Are you sure you want to delete this transaction? This action cannot be undone.'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
                transactionProvider.deleteTransaction(transaction.id!);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transaction deleted')),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
