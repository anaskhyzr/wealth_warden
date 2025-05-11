import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../providers/providers.dart';
import '../models/category.dart';
import '../utils/app_theme.dart';

class AddTransactionScreen extends StatefulWidget {
  final bool isExpense;
  final Transaction? transaction;

  const AddTransactionScreen({
    super.key, 
    required this.isExpense, 
    this.transaction
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();
  // Notes controller removed
  
  List<Category> _categories = [];
  DateTime _selectedDate = DateTime.now();
  String _category = 'Other';
  bool _isProcessing = false;
  // Advanced features removed

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.transaction != null) {
      _titleController.text = widget.transaction!.description;
      _amountController.text = widget.transaction!.amount.toString();
      _category = widget.transaction!.category;
      _selectedDate = widget.transaction!.date;
      // Notes initialization removed
    }
    _dateController.text = DateFormat('MMM dd, yyyy').format(_selectedDate);
  }
  
  // Speech recognition initialization removed due to package compatibility issues

  Future<void> _loadCategories() async {
    try {
      final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
      await categoryProvider.loadCategories();
      
      // Get categories based on transaction type (expense or income)
      final categories = categoryProvider.categories.where(
        (c) => c.type.toLowerCase() == (widget.isExpense ? 'expense' : 'income')
      ).toList();
      
      setState(() {
        _categories = categories;
        if (categories.isNotEmpty) {
          // If editing, keep the existing category, otherwise set default
          if (widget.transaction == null || _category == 'Other') {
            _category = categories[0].name;
          }
        }
      });
    } catch (e) {
      debugPrint('Error loading categories: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load categories: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    // Notes controller removed
    super.dispose();
  }
  
  // Advanced input features removed
  
  // Date picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)), // Allow today and yesterday
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primaryGreen,
              onPrimary: Colors.white,
              surface: AppColors.darkCard,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: AppColors.darkBackground,
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('MMM dd, yyyy').format(_selectedDate);
      });
    }
  }
  
  // Save transaction
  Future<void> _saveTransaction() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isProcessing = true);
      
      try {
        final amount = double.parse(_amountController.text.trim());
        // If description is empty, use category name instead
        String description = _titleController.text.trim();
        if (description.isEmpty) {
          description = _category; // Use category name as description
        }
        
        final transaction = Transaction(
          id: widget.transaction?.id,
          description: description,
          amount: amount,
          date: _selectedDate,
          category: _category,
          type: widget.isExpense ? 'expense' : 'income',
          notes: null, // Notes field removed
        );
        
        final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
        
        if (widget.transaction == null) {
          // Add new transaction
          await transactionProvider.addTransaction(transaction);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Transaction added successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          // Update existing transaction
          await transactionProvider.updateTransaction(transaction);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Transaction updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
        
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        debugPrint('Error saving transaction: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save transaction: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transaction == null 
          ? widget.isExpense ? 'Add Expense' : 'Add Income'
          : widget.isExpense ? 'Edit Expense' : 'Edit Income'
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Amount Field
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '\$',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter an amount';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12), // Reduced spacing
                
                // Category Dropdown
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Reduced padding
                  ),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category.name,
                      child: Text(category.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _category = value;
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a category';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12), // Reduced spacing
                
                // Description Field
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Reduced padding
                  ),
                  // Description is now optional
                  validator: (value) {
                    // No validation needed as description is optional
                    return null;
                  },
                ),
                
                const SizedBox(height: 12), // Reduced spacing
                TextFormField(
                  controller: _dateController,
                  readOnly: true,
                  onTap: () => _selectDate(context),
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Added consistent padding
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                ),
                // Notes field removed as requested
                const SizedBox(height: 16), // Reduced spacing

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 45, // Reduced height
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _saveTransaction,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10), // Smaller radius
                      ),
                    ),
                    child: _isProcessing
                      ? const SizedBox(
                          height: 18, // Smaller indicator
                          width: 18, // Smaller indicator
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          widget.transaction == null 
                            ? 'Add Transaction' 
                            : 'Update Transaction',
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
