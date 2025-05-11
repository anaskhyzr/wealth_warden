import 'package:flutter/material.dart';
import '../models/category.dart' as model;
import '../db/database_helper.dart';

class CategoryProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<model.Category> _categories = [];
  List<model.Category> _expenseCategories = [];
  List<model.Category> _incomeCategories = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<model.Category> get categories => _categories;
  List<model.Category> get expenseCategories => _expenseCategories;
  List<model.Category> get incomeCategories => _incomeCategories;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Initialize and load categories
  Future<void> loadCategories() async {
    _setLoading(true);
    _clearError();
    
    try {
      final allCategories = await _dbHelper.getCategories();
      _categories = allCategories;
      
      // Filter categories by type
      _expenseCategories = allCategories.where((c) => c.isExpense).toList();
      _incomeCategories = allCategories.where((c) => !c.isExpense).toList();
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to load categories: ${e.toString()}');
      debugPrint('Error loading categories: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Get expense categories
  List<model.Category> getExpenseCategories() {
    return _expenseCategories;
  }

  // Get income categories
  List<model.Category> getIncomeCategories() {
    return _incomeCategories;
  }

  // Get categories by type
  Future<void> loadCategoriesByType(bool isExpense) async {
    _setLoading(true);
    _clearError();
    
    try {
      final filteredCategories = await _dbHelper.getCategories(isExpense: isExpense);
      
      if (isExpense) {
        _expenseCategories = filteredCategories;
      } else {
        _incomeCategories = filteredCategories;
      }
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to load categories: ${e.toString()}');
      debugPrint('Error loading categories: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Add a new category
  Future<bool> addCategory(model.Category category) async {
    _setLoading(true);
    _clearError();
    
    try {
      final success = await _dbHelper.addCategory(category);
      if (success) {
        // Reload all categories
        await loadCategories();
        return true;
      }
      _setError('Failed to add category');
      return false;
    } catch (e) {
      _setError('Failed to add category: ${e.toString()}');
      debugPrint('Error adding category: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Update an existing category
  Future<bool> updateCategory(model.Category category) async {
    _setLoading(true);
    _clearError();
    
    try {
      final success = await _dbHelper.updateCategory(category);
      if (success) {
        // Reload all categories
        await loadCategories();
        return true;
      }
      _setError('Failed to update category');
      return false;
    } catch (e) {
      _setError('Failed to update category: ${e.toString()}');
      debugPrint('Error updating category: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Delete a category
  Future<bool> deleteCategory(int id) async {
    _setLoading(true);
    _clearError();
    
    try {
      final success = await _dbHelper.deleteCategory(id);
      if (success) {
        // Reload all categories
        await loadCategories();
        return true;
      }
      _setError('Failed to delete category');
      return false;
    } catch (e) {
      _setError('Failed to delete category: ${e.toString()}');
      debugPrint('Error deleting category: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Reset to default categories
  Future<void> resetToDefaultCategories() async {
    _setLoading(true);
    _clearError();
    
    try {
      await _dbHelper.refreshCategories();
      await loadCategories();
    } catch (e) {
      _setError('Failed to reset categories: ${e.toString()}');
      debugPrint('Error resetting categories: $e');
    } finally {
      _setLoading(false);
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

  // Get category icon data
  IconData getCategoryIcon(String categoryName) {
    // Use a map of predefined icons for common categories
    final Map<String, IconData> iconMap = {
      'Food': Icons.restaurant,
      'Transportation': Icons.directions_car,
      'Housing': Icons.home,
      'Entertainment': Icons.movie,
      'Shopping': Icons.shopping_cart,
      'Health': Icons.medical_services,
      'Education': Icons.school,
      'Salary': Icons.account_balance_wallet,
      'Freelance': Icons.work,
      'Investment': Icons.trending_up,
      'Gift': Icons.card_giftcard,
      'Other': Icons.category,
      'Other Income': Icons.attach_money,
    };
    
    // Return the icon from the map or a default icon
    return iconMap[categoryName] ?? Icons.category;
  }

  // Get category color based on category name
  Color getCategoryColor(String categoryName) {
    // Define a map of category colors or use a deterministic approach
    final Map<String, Color> categoryColors = {
      'Food': Colors.orange,
      'Transportation': Colors.blue,
      'Housing': Colors.green,
      'Entertainment': Colors.purple,
      'Shopping': Colors.pink,
      'Health': Colors.red,
      'Education': Colors.indigo,
      'Salary': Colors.teal,
      'Investment': Colors.amber,
      'Gift': Colors.deepPurple,
    };
    
    // Return the color if it exists in the map, otherwise use a default color
    return categoryColors[categoryName] ?? 
      // Generate a color based on the category name for consistency
      Color((categoryName.hashCode & 0xFFFFFF) | 0xFF000000);
  }
}
