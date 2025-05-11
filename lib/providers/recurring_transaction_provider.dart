import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/transaction.dart';
import '../db/database_helper.dart';

class RecurringTransaction {
  final int? id;
  final String description;
  final double amount;
  final String type;
  final String category;
  final String frequency; // 'daily', 'weekly', 'monthly', 'yearly'
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;

  RecurringTransaction({
    this.id,
    required this.description,
    required this.amount,
    required this.type,
    required this.category,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.isActive = true,
  });

  factory RecurringTransaction.fromJson(Map<String, dynamic> json) {
    return RecurringTransaction(
      id: json['id'] as int?,
      description: json['description'] as String,
      amount: json['amount'] as double,
      type: json['type'] as String,
      category: json['category'] as String,
      frequency: json['frequency'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate'] as String) : null,
      isActive: json['isActive'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'description': description,
      'amount': amount,
      'type': type,
      'category': category,
      'frequency': frequency,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isActive': isActive,
    };
  }

  RecurringTransaction copyWith({
    int? id,
    String? description,
    double? amount,
    String? type,
    String? category,
    String? frequency,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
    );
  }
}

class RecurringTransactionProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<RecurringTransaction> _recurringTransactions = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<RecurringTransaction> get recurringTransactions => _recurringTransactions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Initialize and load recurring transactions
  Future<void> loadRecurringTransactions() async {
    _setLoading(true);
    _clearError();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final recurringJson = prefs.getString('recurring_transactions');
      
      if (recurringJson != null) {
        final List<dynamic> decoded = jsonDecode(recurringJson);
        _recurringTransactions = decoded.map((item) => RecurringTransaction.fromJson(item)).toList();
      }
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to load recurring transactions: ${e.toString()}');
      debugPrint('Error loading recurring transactions: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Save recurring transactions
  Future<void> _saveRecurringTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recurringJson = jsonEncode(_recurringTransactions.map((t) => t.toJson()).toList());
      await prefs.setString('recurring_transactions', recurringJson);
    } catch (e) {
      _setError('Failed to save recurring transactions: ${e.toString()}');
      debugPrint('Error saving recurring transactions: $e');
    }
  }

  // Add a new recurring transaction
  Future<bool> addRecurringTransaction(RecurringTransaction transaction) async {
    _setLoading(true);
    _clearError();
    
    try {
      // Generate a unique ID
      final newId = _recurringTransactions.isEmpty 
          ? 1 
          : _recurringTransactions.map((t) => t.id ?? 0).reduce((a, b) => a > b ? a : b) + 1;
      
      final newTransaction = transaction.copyWith(id: newId);
      _recurringTransactions.add(newTransaction);
      
      await _saveRecurringTransactions();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to add recurring transaction: ${e.toString()}');
      debugPrint('Error adding recurring transaction: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Update an existing recurring transaction
  Future<bool> updateRecurringTransaction(RecurringTransaction transaction) async {
    _setLoading(true);
    _clearError();
    
    try {
      final index = _recurringTransactions.indexWhere((t) => t.id == transaction.id);
      
      if (index < 0) {
        _setError('Recurring transaction not found');
        return false;
      }
      
      _recurringTransactions[index] = transaction;
      
      await _saveRecurringTransactions();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to update recurring transaction: ${e.toString()}');
      debugPrint('Error updating recurring transaction: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Delete a recurring transaction
  Future<bool> deleteRecurringTransaction(int id) async {
    _setLoading(true);
    _clearError();
    
    try {
      _recurringTransactions.removeWhere((t) => t.id == id);
      await _saveRecurringTransactions();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to delete recurring transaction: ${e.toString()}');
      debugPrint('Error deleting recurring transaction: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Toggle active status of a recurring transaction
  Future<bool> toggleRecurringTransactionStatus(int id, bool isActive) async {
    _setLoading(true);
    _clearError();
    
    try {
      final index = _recurringTransactions.indexWhere((t) => t.id == id);
      
      if (index < 0) {
        _setError('Recurring transaction not found');
        return false;
      }
      
      _recurringTransactions[index] = _recurringTransactions[index].copyWith(isActive: isActive);
      
      await _saveRecurringTransactions();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to update recurring transaction status: ${e.toString()}');
      debugPrint('Error updating recurring transaction status: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Process due recurring transactions
  Future<void> processDueRecurringTransactions() async {
    _setLoading(true);
    _clearError();
    
    try {
      final now = DateTime.now();
      final List<Transaction> transactionsToAdd = [];
      
      for (final recurring in _recurringTransactions) {
        if (!recurring.isActive) continue;
        
        // Check if end date has passed
        if (recurring.endDate != null && recurring.endDate!.isBefore(now)) {
          continue;
        }
        
        // Check if transaction is due based on frequency
        bool isDue = false;
        final lastProcessed = await _getLastProcessedDate(recurring.id!);
        
        if (lastProcessed == null) {
          // First time processing this recurring transaction
          isDue = recurring.startDate.isBefore(now) || recurring.startDate.isAtSameMomentAs(now);
        } else {
          switch (recurring.frequency) {
            case 'daily':
              isDue = lastProcessed.add(const Duration(days: 1)).isBefore(now);
              break;
            case 'weekly':
              isDue = lastProcessed.add(const Duration(days: 7)).isBefore(now);
              break;
            case 'monthly':
              // Simple approach: add 30 days
              isDue = lastProcessed.add(const Duration(days: 30)).isBefore(now);
              break;
            case 'yearly':
              isDue = lastProcessed.add(const Duration(days: 365)).isBefore(now);
              break;
          }
        }
        
        if (isDue) {
          // Create a new transaction
          final transaction = Transaction(
            description: recurring.description,
            amount: recurring.amount,
            date: now,
            type: recurring.type,
            category: recurring.category,
          );
          
          transactionsToAdd.add(transaction);
          
          // Update last processed date
          await _setLastProcessedDate(recurring.id!, now);
        }
      }
      
      // Add all due transactions to the database
      for (final transaction in transactionsToAdd) {
        await _dbHelper.addTransaction(transaction);
      }
      
      if (transactionsToAdd.isNotEmpty) {
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to process recurring transactions: ${e.toString()}');
      debugPrint('Error processing recurring transactions: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Helper methods to track last processed dates
  Future<DateTime?> _getLastProcessedDate(int recurringId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateStr = prefs.getString('last_processed_$recurringId');
      return dateStr != null ? DateTime.parse(dateStr) : null;
    } catch (e) {
      debugPrint('Error getting last processed date: $e');
      return null;
    }
  }

  Future<void> _setLastProcessedDate(int recurringId, DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_processed_$recurringId', date.toIso8601String());
    } catch (e) {
      debugPrint('Error setting last processed date: $e');
    }
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
