import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../db/database_helper.dart';
import 'dart:isolate';

class TransactionProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Transaction> _transactions = [];
  List<Transaction> _filteredTransactions = [];
  double _totalIncome = 0;
  double _totalExpenses = 0;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<Transaction> get transactions => _transactions;
  List<Transaction> get filteredTransactions => _filteredTransactions;
  double get totalIncome => _totalIncome;
  double get totalExpenses => _totalExpenses;
  double get balance => _totalIncome - _totalExpenses;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Load transactions from the database using compute for background processing
  Future<void> loadTransactions() async {
    _setLoading(true);
    
    try {
      final transactions = await _dbHelper.getAllTransactions();
      
      // Use compute to process data off the main thread
      _transactions = await compute(_processTransactions, transactions);
      
      // Calculate totals in the background
      final totals = await compute(_calculateTotalsOffMain, _transactions);
      _totalIncome = totals['income'] as double;
      _totalExpenses = totals['expenses'] as double;
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to load transactions: ${e.toString()}');
      debugPrint('Error loading transactions: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Static method to process transactions off the main thread
  static List<Transaction> _processTransactions(List<Transaction> transactions) {
    // Sort transactions by date (newest first)
    transactions.sort((a, b) => b.date.compareTo(a.date));
    return transactions;
  }
  
  // Static method to calculate totals off the main thread
  static Map<String, double> _calculateTotalsOffMain(List<Transaction> transactions) {
    double income = 0;
    double expenses = 0;
    
    for (final transaction in transactions) {
      if (transaction.type.toLowerCase() == 'income') {
        income += transaction.amount;
      } else {
        expenses += transaction.amount;
      }
    }
    
    return {'income': income, 'expenses': expenses};
  }

  // Filter transactions using compute for background processing
  Future<void> filterTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? type,
    String? category,
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      // First get transactions by date range
      final filtered = await _dbHelper.getTransactions(
        startDate: startDate,
        endDate: endDate,
      );
      
      // Create filter parameters to pass to the compute function
      final filterParams = {
        'transactions': filtered,
        'type': type,
        'category': category,
      };
      
      // Then filter by type and category in a background thread
      _filteredTransactions = await compute(_filterTransactionsOffMain, filterParams);
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to filter transactions: ${e.toString()}');
      debugPrint('Error filtering transactions: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Static method to filter transactions off the main thread
  static List<Transaction> _filterTransactionsOffMain(Map<String, dynamic> params) {
    final List<Transaction> transactions = params['transactions'] as List<Transaction>;
    final String? type = params['type'] as String?;
    final String? category = params['category'] as String?;
    
    return transactions.where((t) {
      bool matches = true;
      
      if (type != null && type.isNotEmpty) {
        matches = matches && t.type == type;
      }
      
      if (category != null && category.isNotEmpty) {
        matches = matches && t.category == category;
      }
      
      return matches;
    }).toList();
  }

  // Add a new transaction with optimized loading
  Future<bool> addTransaction(Transaction transaction) async {
    _setLoading(true);
    _clearError();
    
    try {
      // Add transaction to database
      final id = await _dbHelper.addTransaction(transaction);
      if (id > 0) {
        // Instead of reloading all transactions, just add the new one to the list
        // and update totals in memory - much faster than a full reload
        final newTransaction = Transaction(
          id: id,
          description: transaction.description,
          amount: transaction.amount,
          date: transaction.date,
          category: transaction.category,
          type: transaction.type,
          notes: transaction.notes,
        );
        
        // Update in-memory data in a background thread
        await _updateInMemoryAfterAdd(newTransaction);
        
        return true;
      }
      _setError('Failed to add transaction');
      return false;
    } catch (e) {
      _setError('Failed to add transaction: ${e.toString()}');
      debugPrint('Error adding transaction: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Update in-memory data after adding a transaction
  Future<void> _updateInMemoryAfterAdd(Transaction transaction) async {
    // Update totals based on transaction type
    if (transaction.type.toLowerCase() == 'income') {
      _totalIncome += transaction.amount;
    } else {
      _totalExpenses += transaction.amount;
    }
    
    // Add to transactions list and sort
    _transactions.add(transaction);
    await compute(_sortTransactions, _transactions);
    
    // Notify listeners on the main thread
    notifyListeners();
  }
  
  // Static method to sort transactions off the main thread
  static List<Transaction> _sortTransactions(List<Transaction> transactions) {
    transactions.sort((a, b) => b.date.compareTo(a.date));
    return transactions;
  }

  // Update an existing transaction with optimized loading
  Future<bool> updateTransaction(Transaction transaction) async {
    _setLoading(true);
    _clearError();
    
    try {
      final success = await _dbHelper.updateTransaction(transaction);
      if (success) {
        // Instead of reloading all transactions, just update the existing one
        // and recalculate totals in memory - much faster than a full reload
        await _updateInMemoryAfterEdit(transaction);
        return true;
      }
      _setError('Failed to update transaction');
      return false;
    } catch (e) {
      _setError('Failed to update transaction: ${e.toString()}');
      debugPrint('Error updating transaction: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Update in-memory data after editing a transaction
  Future<void> _updateInMemoryAfterEdit(Transaction transaction) async {
    // Find the old transaction to update
    final oldTransactionIndex = _transactions.indexWhere((t) => t.id == transaction.id);
    
    if (oldTransactionIndex >= 0) {
      final oldTransaction = _transactions[oldTransactionIndex];
      
      // Update totals by removing old values and adding new ones
      if (oldTransaction.type.toLowerCase() == 'income') {
        _totalIncome -= oldTransaction.amount;
      } else {
        _totalExpenses -= oldTransaction.amount;
      }
      
      if (transaction.type.toLowerCase() == 'income') {
        _totalIncome += transaction.amount;
      } else {
        _totalExpenses += transaction.amount;
      }
      
      // Update the transaction in the list
      _transactions[oldTransactionIndex] = transaction;
      
      // Sort transactions if the date changed
      if (oldTransaction.date != transaction.date) {
        await compute(_sortTransactions, _transactions);
      }
      
      // Notify listeners on the main thread
      notifyListeners();
    } else {
      // If transaction not found in memory, do a full reload
      await loadTransactions();
    }
  }

  // Delete a transaction with optimized loading
  Future<bool> deleteTransaction(int id) async {
    _setLoading(true);
    _clearError();
    
    try {
      final success = await _dbHelper.deleteTransaction(id);
      if (success) {
        // Instead of reloading all transactions, just remove the deleted one
        // and update totals in memory - much faster than a full reload
        await _updateInMemoryAfterDelete(id);
        return true;
      }
      _setError('Failed to delete transaction');
      return false;
    } catch (e) {
      _setError('Failed to delete transaction: ${e.toString()}');
      debugPrint('Error deleting transaction: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Update in-memory data after deleting a transaction
  Future<void> _updateInMemoryAfterDelete(int id) async {
    // Find the transaction to delete
    final transactionIndex = _transactions.indexWhere((t) => t.id == id);
    
    if (transactionIndex >= 0) {
      final transaction = _transactions[transactionIndex];
      
      // Update totals by removing the transaction amount
      if (transaction.type.toLowerCase() == 'income') {
        _totalIncome -= transaction.amount;
      } else {
        _totalExpenses -= transaction.amount;
      }
      
      // Remove the transaction from the list
      _transactions.removeAt(transactionIndex);
      
      // Notify listeners on the main thread
      notifyListeners();
    } else {
      // If transaction not found in memory, do a full reload
      await loadTransactions();
    }
  }

  // Get recent transactions (for home screen)
  List<Transaction> getRecentTransactions([int limit = 3]) {
    return _transactions.take(limit).toList();
  }

  // Get top expense categories
  List<Map<String, dynamic>> getTopExpenseCategories(int limit) {
    // Group expenses by category
    final Map<String, double> categoryTotals = {};
    for (var transaction in _transactions) {
      if (transaction.type == 'expense') {
        categoryTotals[transaction.category] = 
            (categoryTotals[transaction.category] ?? 0) + transaction.amount;
      }
    }
    
    // Convert to list and sort
    final List<Map<String, dynamic>> result = categoryTotals.entries
        .map((entry) => {
              'category': entry.key,
              'amount': entry.value,
            })
        .toList();
    
    // Sort by amount (descending)
    result.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
    
    // Return top categories
    return result.take(limit).toList();
  }

  // Get monthly expenses
  double getMonthlyExpenses() {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final nextMonth = DateTime(now.year, now.month + 1);
    
    return _transactions
        .where((t) => 
            t.type == 'expense' && 
            t.date.isAfter(currentMonth.subtract(const Duration(days: 1))) &&
            t.date.isBefore(nextMonth))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // Get monthly income
  double getMonthlyIncome() {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final nextMonth = DateTime(now.year, now.month + 1);
    
    return _transactions
        .where((t) => 
            t.type == 'income' && 
            t.date.isAfter(currentMonth.subtract(const Duration(days: 1))) &&
            t.date.isBefore(nextMonth))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // Get category spending
  double getCategorySpending(String category) {
    return _transactions
        .where((t) => t.type == 'expense' && t.category == category)
        .fold(0.0, (sum, t) => sum + t.amount);
  }
  
  // Get current balance
  double getBalance() {
    return _totalIncome - _totalExpenses;
  }

  // Helper methods
  void _updateTransactionData(List<Transaction> transactions) {
    _transactions = transactions;
    
    double income = 0;
    double expenses = 0;
    
    for (var transaction in transactions) {
      if (transaction.type == 'income') {
        income += transaction.amount;
      } else {
        expenses += transaction.amount;
      }
    }
    
    _totalIncome = income;
    _totalExpenses = expenses;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  // Public method to set loading state from outside the provider
  void setLoading(bool loading) {
    _setLoading(loading);
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}
