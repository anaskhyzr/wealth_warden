import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/transaction.dart';
// Import database helper if needed for future implementation
// import '../db/database_helper.dart';

class Budget {
  final String? id;
  final String category;
  final double limit;
  final String period; // 'monthly', 'weekly', etc.

  Budget({
    this.id,
    required this.category,
    required this.limit,
    required this.period,
  });

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'] as String?,
      category: json['category'] as String,
      limit: json['limit'] as double,
      period: json['period'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'category': category,
      'limit': limit,
      'period': period,
    };
  }
}

class BudgetProvider with ChangeNotifier {
  List<Budget> _budgets = [];
  Map<String, double> _categorySpending = {};
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<Budget> get budgets => _budgets;
  Map<String, double> get categorySpending => _categorySpending;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Initialize and load budgets
  Future<void> loadBudgets() async {
    _setLoading(true);
    _clearError();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final budgetsJson = prefs.getString('budgets');
      
      if (budgetsJson != null) {
        final List<dynamic> decoded = jsonDecode(budgetsJson);
        _budgets = decoded.map((item) => Budget.fromJson(item)).toList();
      }
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to load budgets: ${e.toString()}');
      debugPrint('Error loading budgets: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Save budgets
  Future<void> _saveBudgets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final budgetsJson = jsonEncode(_budgets.map((b) => b.toJson()).toList());
      await prefs.setString('budgets', budgetsJson);
    } catch (e) {
      _setError('Failed to save budgets: ${e.toString()}');
      debugPrint('Error saving budgets: $e');
    }
  }

  // Add a new budget
  Future<bool> addBudget(Budget budget) async {
    _setLoading(true);
    _clearError();
    
    try {
      // Check if budget for this category already exists
      final existingIndex = _budgets.indexWhere((b) => b.category == budget.category);
      
      if (existingIndex >= 0) {
        _budgets[existingIndex] = budget;
      } else {
        _budgets.add(budget);
      }
      
      await _saveBudgets();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to add budget: ${e.toString()}');
      debugPrint('Error adding budget: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Update an existing budget
  Future<bool> updateBudget(Budget updatedBudget) async {
    _setLoading(true);
    _clearError();
    
    try {
      final index = _budgets.indexWhere((b) => b.id == updatedBudget.id || b.category == updatedBudget.category);
      
      if (index < 0) {
        _setError('Budget not found for category: ${updatedBudget.category}');
        return false;
      }
      
      _budgets[index] = updatedBudget;
      
      await _saveBudgets();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to update budget: ${e.toString()}');
      debugPrint('Error updating budget: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Delete a budget
  Future<bool> deleteBudget(String? id) async {
    _setLoading(true);
    _clearError();
    
    try {
      if (id != null) {
        _budgets.removeWhere((b) => b.id == id);
      } else {
        _setError('Budget ID is required for deletion');
        return false;
      }
      await _saveBudgets();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to delete budget: ${e.toString()}');
      debugPrint('Error deleting budget: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Calculate spending for each category based on transactions
  void calculateCategorySpending(List<Transaction> transactions, String period) {
    _categorySpending = {};
    
    // Filter transactions based on period
    final DateTime now = DateTime.now();
    final List<Transaction> filteredTransactions = transactions.where((t) {
      if (period == 'monthly') {
        return t.date.month == now.month && t.date.year == now.year;
      } else if (period == 'weekly') {
        final difference = now.difference(t.date).inDays;
        return difference <= 7;
      } else if (period == 'yearly') {
        return t.date.year == now.year;
      }
      return false;
    }).toList();
    
    // Calculate spending for each category
    for (var transaction in filteredTransactions) {
      if (transaction.type == 'expense') {
        final category = transaction.category;
        _categorySpending[category] = (_categorySpending[category] ?? 0) + transaction.amount;
      }
    }
    
    notifyListeners();
  }

  // Get budget for a specific category
  Budget? getBudgetForCategory(String category) {
    final index = _budgets.indexWhere((b) => b.category == category);
    return index >= 0 ? _budgets[index] : null;
  }

  // Get spending percentage for a category
  double getSpendingPercentage(String category) {
    final budget = getBudgetForCategory(category);
    if (budget == null) return 0;
    
    final spending = _categorySpending[category] ?? 0;
    return (spending / budget.limit) * 100;
  }

  // Get total budget across all categories
  double getTotalBudget() {
    return _budgets.fold(0.0, (sum, budget) => sum + budget.limit);
  }

  // Helper methods
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
