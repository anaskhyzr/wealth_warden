import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../providers/providers.dart';
import '../utils/app_theme.dart';

class CategoriesScreen extends StatefulWidget {
  final bool isExpense;
  
  const CategoriesScreen({
    super.key,
    required this.isExpense,
  });

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> with AutomaticKeepAliveClientMixin {
  bool _isLoading = false;
  List<Category> _expenseCategories = [];
  List<Category> _incomeCategories = [];
  bool _showExpenseCategories = true;
  
  // For adding/editing categories
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedIcon = 'shopping_cart';
  // Removed isDefault as it's not in the Category model
  bool _isEditing = false;
  int? _editingCategoryId;
  
  // Icon map for both expense and income categories
  final Map<String, IconData> _iconMap = {
    'shopping_cart': Icons.shopping_cart,
    'restaurant': Icons.restaurant,
    'directions_car': Icons.directions_car,
    'receipt_long': Icons.receipt_long,
    'medical_services': Icons.medical_services,
    'movie': Icons.movie,
    'school': Icons.school,
    'shopping_bag': Icons.shopping_bag,
    'home': Icons.home,
    'flight': Icons.flight,
    'fitness_center': Icons.fitness_center,
    'pets': Icons.pets,
    'account_balance_wallet': Icons.account_balance_wallet,
    'work': Icons.work,
    'trending_up': Icons.trending_up,
    'card_giftcard': Icons.card_giftcard,
    'star': Icons.star,
    'house': Icons.house,
    'business': Icons.business,
    'computer': Icons.computer,
    'category': Icons.category,
  };
  
  @override
  bool get wantKeepAlive => true; // Keep state alive when switching tabs
  
  @override
  void initState() {
    super.initState();
    _loadCategories();
    _showExpenseCategories = widget.isExpense;
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    
    try {
      final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
      await categoryProvider.loadCategories();
      
      setState(() {
        _expenseCategories = categoryProvider.categories
            .where((c) => c.type.toLowerCase() == 'expense')
            .toList();
        _incomeCategories = categoryProvider.categories
            .where((c) => c.type.toLowerCase() == 'income')
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Failed to load categories: ${e.toString()}');
      }
    }
  }
  
  void _resetForm() {
    _nameController.clear();
    _descriptionController.clear();
    _selectedIcon = 'shopping_cart';
    // isDefault removed
    _isEditing = false;
    _editingCategoryId = null;
  }
  
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  Future<void> _addCategory() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
      
      final category = Category(
        id: _isEditing ? _editingCategoryId : null,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        icon: _selectedIcon,
        // isDefault removed
        // type parameter removed as it's a getter in the Category class
        isExpense: _showExpenseCategories,
      );
      
      bool success;
      if (_isEditing) {
        success = await categoryProvider.updateCategory(category);
        if (success) {
          _showSuccess('Category updated successfully');
        }
      } else {
        success = await categoryProvider.addCategory(category);
        if (success) {
          _showSuccess('Category added successfully');
        }
      }
      
      if (success) {
        _resetForm();
        await _loadCategories();
      } else {
        _showError('Failed to ${_isEditing ? 'update' : 'add'} category');
      }
    } catch (e) {
      _showError('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _deleteCategory(Category category) async {
    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() => _isLoading = true);
    
    try {
      final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
      final success = await categoryProvider.deleteCategory(category.id!);
      
      if (success) {
        _showSuccess('Category deleted successfully');
        await _loadCategories();
      } else {
        _showError('Failed to delete category');
      }
    } catch (e) {
      _showError('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _editCategory(Category category) {
    setState(() {
      _isEditing = true;
      _editingCategoryId = category.id;
      _nameController.text = category.name;
      _descriptionController.text = category.description;
      _selectedIcon = category.icon;
      // isDefault removed
      _showExpenseCategories = category.isExpense;
    });
    
    _showAddCategoryDialog();
  }
  
  void _showAddCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(_isEditing ? 'Edit Category' : 'Add Category'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Category Type:'),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        label: Text('Expense'),
                        icon: Icon(Icons.remove_circle_outline),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text('Income'),
                        icon: Icon(Icons.add_circle_outline),
                      ),
                    ],
                    selected: {_showExpenseCategories},
                    onSelectionChanged: (Set<bool> newSelection) {
                      setState(() {
                        _showExpenseCategories = newSelection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Choose an Icon:'),
                  SizedBox(
                    height: 200,
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: _iconMap.length,
                      itemBuilder: (context, index) {
                        final iconEntry = _iconMap.entries.elementAt(index);
                        return InkWell(
                          onTap: () => setState(() => _selectedIcon = iconEntry.key),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _selectedIcon == iconEntry.key
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              iconEntry.value,
                              color: _selectedIcon == iconEntry.key
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Default category checkbox removed
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _resetForm();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  _addCategory();
                }
              },
              child: Text(_isEditing ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Category',
            onPressed: () {
              _resetForm();
              _showAddCategoryDialog();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Tab selector
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        label: Text('Expense Categories'),
                        icon: Icon(Icons.remove_circle_outline),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text('Income Categories'),
                        icon: Icon(Icons.add_circle_outline),
                      ),
                    ],
                    selected: {_showExpenseCategories},
                    onSelectionChanged: (Set<bool> newSelection) {
                      setState(() {
                        _showExpenseCategories = newSelection.first;
                      });
                    },
                  ),
                ),
                
                // Category list
                Expanded(
                  child: _buildCategoryList(),
                ),
              ],
            ),
    );
  }
  
  Widget _buildCategoryList() {
    final categories = _showExpenseCategories ? _expenseCategories : _incomeCategories;
    
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No categories found',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                _resetForm();
                _showAddCategoryDialog();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Category'),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final iconData = _iconMap[category.icon] ?? Icons.category;
        final color = category.isExpense ? AppColors.categoryRed : AppColors.primaryGreen;
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(iconData, color: color),
            ),
            title: Text(
              category.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(category.description),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Default category chip removed
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editCategory(category),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteCategory(category),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
