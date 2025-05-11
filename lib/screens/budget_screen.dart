import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../utils/app_theme.dart';
// Using the Budget model from the provider to avoid conflicts

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  String _selectedPeriod = 'Monthly';
  final List<String> _periodOptions = ['Weekly', 'Monthly', 'Yearly'];

  @override
  void initState() {
    super.initState();
    _loadBudgets();
  }

  Future<void> _loadBudgets() async {
    await Provider.of<BudgetProvider>(context, listen: false).loadBudgets();
    await Provider.of<CategoryProvider>(context, listen: false).loadCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Planning'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadBudgets,
        color: AppColors.primaryGreen,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPeriodSelector(),
                const SizedBox(height: 24),
                _buildBudgetSummary(),
                const SizedBox(height: 24),
                _buildBudgetList(),
                const SizedBox(height: 24),
                _buildAddBudgetButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: AppTheme.roundedBoxDecoration(
        color: AppColors.darkCard,
        radius: 12,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today, size: 18),
          const SizedBox(width: 8),
          Text(
            'Budget Period:',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _selectedPeriod,
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedPeriod = newValue;
                });
              }
            },
            items: _periodOptions.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.primaryGreen,
                  ),
                ),
              );
            }).toList(),
            underline: const SizedBox(),
            icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryGreen),
            dropdownColor: AppColors.darkCard,
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetSummary() {
    return Consumer2<BudgetProvider, TransactionProvider>(
      builder: (context, budgetProvider, transactionProvider, child) {
        final totalBudget = budgetProvider.getTotalBudget();
        final totalSpent = transactionProvider.getMonthlyExpenses();
        final remaining = totalBudget - totalSpent;
        final percentage = totalBudget > 0 ? (totalSpent / totalBudget * 100).clamp(0, 100) : 0;
        
        final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
        final currencySymbol = settingsProvider.currencySymbol;
        
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
                    'Total Budget',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '$currencySymbol${totalBudget.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Spent',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.darkTextSecondary,
                    ),
                  ),
                  Text(
                    '$currencySymbol${totalSpent.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: totalSpent > totalBudget ? AppColors.categoryRed : AppColors.darkTextPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Remaining',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.darkTextSecondary,
                    ),
                  ),
                  Text(
                    '$currencySymbol${remaining.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: remaining < 0 ? AppColors.categoryRed : AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: AppColors.darkSurface,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    percentage > 90 ? AppColors.categoryRed : AppColors.primaryGreen,
                  ),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${percentage.toInt()}% of budget used',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: percentage > 90 ? AppColors.categoryRed : AppColors.darkTextSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBudgetList() {
    return Consumer2<BudgetProvider, CategoryProvider>(
      builder: (context, budgetProvider, categoryProvider, child) {
        final budgets = budgetProvider.budgets;
        final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
        final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
        final currencySymbol = settingsProvider.currencySymbol;
        
        if (budgets.isEmpty) {
          return Center(
            child: Column(
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 64,
                  color: AppColors.darkTextSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No budgets set',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a budget to track your spending',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: budgets.length,
          itemBuilder: (context, index) {
            final budget = budgets[index];
            final spent = transactionProvider.getCategorySpending(budget.category);
            final percentage = budget.limit > 0 ? (spent / budget.limit * 100).clamp(0, 100) : 0;
            
            final categoryIcon = categoryProvider.getCategoryIcon(budget.category);
            final categoryColor = categoryProvider.getCategoryColor(budget.category);
            
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: AppTheme.roundedBoxDecoration(
                color: AppColors.darkCard,
                radius: 16,
              ),
              child: Column(
                children: [
                  ListTile(
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
                      budget.category,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      'Budget: $currencySymbol${budget.limit.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showBudgetDialog(budget),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Spent: $currencySymbol${spent.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Text(
                              'Remaining: $currencySymbol${(budget.limit - spent).toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: spent > budget.limit ? AppColors.categoryRed : AppColors.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: percentage / 100,
                            backgroundColor: AppColors.darkSurface,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              percentage > 90 ? AppColors.categoryRed : categoryColor,
                            ),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${percentage.toInt()}%',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: percentage > 90 ? AppColors.categoryRed : AppColors.darkTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAddBudgetButton() {
    return Center(
      child: ElevatedButton.icon(
        onPressed: () => _showBudgetDialog(null),
        icon: const Icon(Icons.add),
        label: const Text('Add New Budget'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    );
  }

  Future<void> _showBudgetDialog(Budget? budget) async {
    final isEditing = budget != null;
    final titleController = TextEditingController(text: isEditing ? budget.limit.toString() : '');
    String selectedCategory = isEditing ? budget.category : '';
    
    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(isEditing ? 'Edit Budget' : 'Create Budget'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Consumer<CategoryProvider>(
                    builder: (context, categoryProvider, child) {
                      final categories = categoryProvider.getExpenseCategories();
                      
                      if (categories.isEmpty) {
                        return const Text('No categories available. Please create a category first.');
                      }
                      
                      if (selectedCategory.isEmpty && categories.isNotEmpty) {
                        selectedCategory = categories.first.name;
                      }
                      
                      return DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        value: selectedCategory,
                        items: categories.map((category) {
                          return DropdownMenuItem<String>(
                            value: category.name,
                            child: Text(category.name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              selectedCategory = value;
                            });
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Budget Amount',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              if (isEditing)
                TextButton(
                  onPressed: () async {
                    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
                    await budgetProvider.deleteBudget(budget.id!);
                    if (!mounted) return;
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Delete',
                    style: TextStyle(color: AppColors.categoryRed),
                  ),
                ),
              TextButton(
                onPressed: () async {
                  if (selectedCategory.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a category')),
                    );
                    return;
                  }
                  
                  final amountText = titleController.text.trim();
                  if (amountText.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a budget amount')),
                    );
                    return;
                  }
                  
                  double? amount = double.tryParse(amountText);
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid budget amount')),
                    );
                    return;
                  }
                  
                  final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
                  
                  if (isEditing) {
                    final updatedBudget = Budget(
                      id: budget.id,
                      category: selectedCategory,
                      limit: amount,
                      period: _selectedPeriod.toLowerCase(),
                    );
                    await budgetProvider.updateBudget(updatedBudget);
                  } else {
                    final newBudget = Budget(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      category: selectedCategory,
                      limit: amount,
                      period: _selectedPeriod.toLowerCase(),
                    );
                    await budgetProvider.addBudget(newBudget);
                  }
                  
                  if (!mounted) return;
                  Navigator.of(context).pop();
                },
                child: Text(isEditing ? 'Update' : 'Create'),
              ),
            ],
          );
        },
      ),
    );
  }
}
