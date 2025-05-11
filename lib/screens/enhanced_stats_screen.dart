import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/providers.dart';
import '../models/transaction.dart';
import '../utils/app_theme.dart';
import 'transaction_history_screen.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with AutomaticKeepAliveClientMixin {
  int _selectedPeriodIndex = 0;
  final List<String> _periods = ['This Month', 'Last Month', '3 Months', '6 Months', 'Year'];
  bool _isLoading = false;
  
  @override
  bool get wantKeepAlive => true; // Keep state alive when switching tabs
  
  // Chart data
  List<FlSpot> _incomeSpots = [];
  List<FlSpot> _expenseSpots = [];
  double _maxY = 1000;
  
  // Category data
  Map<String, double> _categoryExpenses = {};
  Map<String, double> _categoryIncome = {};
  
  @override
  void initState() {
    super.initState();
    _refreshData();
  }
  
  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _refreshData() async {
    if (_isLoading) return;
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Ensure transactions are loaded
      final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
      await transactionProvider.loadTransactions();
      
      // Process data directly without compute to simplify
      _processChartData();
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error refreshing stats data: $e');
      if (mounted) {
        _showError('Failed to load statistics');
        setState(() => _isLoading = false);
      }
    }
  }
  
  // Static method that can be run in a separate isolate
  static Map<String, dynamic> _processDataInBackground(List<Transaction> transactions) {
    // Process chart data
    final Map<DateTime, double> incomeByDay = {};
    final Map<DateTime, double> expenseByDay = {};
    final Map<String, double> categoryExpenses = {};
    final Map<String, double> categoryIncome = {};
    
    // Get date range for chart
    final DateTime now = DateTime.now();
    final DateTime startDate = now.subtract(const Duration(days: 30)); // Default to monthly view
    final int daysDifference = now.difference(startDate).inDays;
    
    // Initialize with zeros for all days
    for (int i = 0; i <= daysDifference; i++) {
      final day = startDate.add(Duration(days: i));
      final normalizedDay = DateTime(day.year, day.month, day.day);
      incomeByDay[normalizedDay] = 0;
      expenseByDay[normalizedDay] = 0;
    }
    
    // Process transactions in a single pass to improve performance
    for (final transaction in transactions) {
      final date = DateTime(transaction.date.year, transaction.date.month, transaction.date.day);
      final isIncome = transaction.type.toLowerCase() == 'income';
      
      // Update daily totals
      if (isIncome) {
        incomeByDay[date] = (incomeByDay[date] ?? 0.0) + transaction.amount.toDouble();
      } else {
        expenseByDay[date] = (expenseByDay[date] ?? 0.0) + transaction.amount.toDouble();
      }
      
      // Update category totals
      final category = transaction.category;
      if (isIncome) {
        categoryIncome[category] = (categoryIncome[category] ?? 0.0) + transaction.amount.toDouble();
      } else {
        categoryExpenses[category] = (categoryExpenses[category] ?? 0.0) + transaction.amount.toDouble();
      }
    }
    
    // Convert to chart data points
    final List<FlSpot> incomeSpots = [];
    final List<FlSpot> expenseSpots = [];
    double maxAmount = 0;
    
    // Sort dates
    final sortedDates = incomeByDay.keys.toList()..sort();
    
    for (int i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      final income = incomeByDay[date] ?? 0;
      final expense = expenseByDay[date] ?? 0;
      
      incomeSpots.add(FlSpot(i.toDouble(), income));
      expenseSpots.add(FlSpot(i.toDouble(), expense));
      
      maxAmount = [maxAmount, income, expense].reduce((curr, next) => curr > next ? curr : next);
    }
    
    // Set max Y with some padding
    final maxY = maxAmount > 0 ? (maxAmount * 1.2) : 1000;
    
    return {
      'incomeSpots': incomeSpots,
      'expenseSpots': expenseSpots,
      'maxY': maxY,
      'categoryExpenses': categoryExpenses,
      'categoryIncome': categoryIncome,
    };
  }
  
  void _processChartData() {
    final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
    final transactions = _getFilteredTransactions(transactionProvider);
    
    // Group transactions by day
    final Map<DateTime, double> incomeByDay = {};
    final Map<DateTime, double> expenseByDay = {};
    
    // Get date range for chart
    final DateTime now = DateTime.now();
    final DateTime startDate = _getStartDate();
    final int daysDifference = now.difference(startDate).inDays;
    
    // Initialize with zeros for all days
    for (int i = 0; i <= daysDifference; i++) {
      final day = startDate.add(Duration(days: i));
      final normalizedDay = DateTime(day.year, day.month, day.day);
      incomeByDay[normalizedDay] = 0;
      expenseByDay[normalizedDay] = 0;
    }
    
    // Aggregate transactions by day
    for (final transaction in transactions) {
      final date = DateTime(transaction.date.year, transaction.date.month, transaction.date.day);
      if (transaction.type.toLowerCase() == 'income') {
        incomeByDay[date] = (incomeByDay[date] ?? 0) + transaction.amount;
      } else {
        expenseByDay[date] = (expenseByDay[date] ?? 0) + transaction.amount;
      }
    }
    
    // Convert to chart data points
    _incomeSpots = [];
    _expenseSpots = [];
    double maxAmount = 0;
    
    // Sort dates
    final sortedDates = incomeByDay.keys.toList()..sort();
    
    for (int i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      final income = incomeByDay[date] ?? 0;
      final expense = expenseByDay[date] ?? 0;
      
      _incomeSpots.add(FlSpot(i.toDouble(), income));
      _expenseSpots.add(FlSpot(i.toDouble(), expense));
      
      maxAmount = [maxAmount, income, expense].reduce((curr, next) => curr > next ? curr : next);
    }
    
    // Set max Y with some padding
    _maxY = maxAmount > 0 ? (maxAmount * 1.2) : 1000;
  }
  
  void _processCategoryData() {
    final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
    final transactions = _getFilteredTransactions(transactionProvider);
    
    _categoryExpenses = {};
    _categoryIncome = {};
    
    for (final transaction in transactions) {
      if (transaction.type.toLowerCase() == 'expense') {
        _categoryExpenses[transaction.category] = 
            (_categoryExpenses[transaction.category] ?? 0) + transaction.amount;
      } else {
        _categoryIncome[transaction.category] = 
            (_categoryIncome[transaction.category] ?? 0) + transaction.amount;
      }
    }
  }
  
  List<Transaction> _getFilteredTransactions(TransactionProvider provider) {
    final transactions = provider.transactions;
    final startDate = _getStartDate();
    
    return transactions.where((t) => 
      t.date.isAfter(startDate.subtract(const Duration(days: 1)))
    ).toList();
  }
  
  DateTime _getStartDate() {
    final now = DateTime.now();
    
    switch (_selectedPeriodIndex) {
      case 0: // This Month
        return DateTime(now.year, now.month, 1);
      case 1: // Last Month
        return now.month == 1
            ? DateTime(now.year - 1, 12, 1)
            : DateTime(now.year, now.month - 1, 1);
      case 2: // 3 Months
        return now.month > 3
            ? DateTime(now.year, now.month - 3, 1)
            : DateTime(now.year - 1, now.month + 9, 1);
      case 3: // 6 Months
        return now.month > 6
            ? DateTime(now.year, now.month - 6, 1)
            : DateTime(now.year - 1, now.month + 6, 1);
      case 4: // Year
        return DateTime(now.year - 1, now.month, now.day);
      default:
        return DateTime(now.year, now.month, 1);
    }
  }
  
  void _onPeriodChanged(int index) {
    if (_selectedPeriodIndex != index) {
      setState(() {
        _selectedPeriodIndex = index;
      });
      _refreshData();
    }
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    
    // Calculate financial metrics
    final totalIncome = _calculateTotalIncome(transactionProvider);
    final totalExpenses = _calculateTotalExpenses(transactionProvider);
    final savings = totalIncome - totalExpenses;
    final savingsRate = totalIncome > 0 ? (savings / totalIncome) * 100 : 0;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        elevation: 0,
        actions: [
          // View All Transactions button
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View All Transactions',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TransactionHistoryScreen(),
                ),
              );
            },
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh data',
            onPressed: _refreshData,
          ),
          // Filter button that shows a dialog with all filter options
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Filter Options'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Time period selector
                      const Text('Time Period', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: List.generate(
                          _periods.length,
                          (index) => FilterChip(
                            label: Text(_periods[index]),
                            selected: _selectedPeriodIndex == index,
                            onSelected: (selected) {
                              if (selected) {
                                Navigator.pop(context);
                                _onPeriodChanged(index);
                              }
                            },
                          ),
                        ),
                      ),
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
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: AppColors.primaryGreen,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Current period indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.date_range, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Period: ${_periods[_selectedPeriodIndex]}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Text(
                              'Tap filter icon to change',
                              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      ),
                      
                      // Financial summary cards
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Income',
                                '$currencySymbol${totalIncome.toStringAsFixed(2)}',
                                AppColors.primaryGreen,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                'Expenses',
                                '$currencySymbol${totalExpenses.toStringAsFixed(2)}',
                                AppColors.categoryRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Savings cards
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Savings',
                                '$currencySymbol${savings.toStringAsFixed(2)}',
                                savings >= 0 ? AppColors.primaryGreen : AppColors.categoryRed,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                'Savings Rate',
                                '${savingsRate.toStringAsFixed(1)}%',
                                savingsRate >= 0 ? AppColors.primaryGreen : AppColors.categoryRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Cash flow chart section
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Cash flow chart
                            _buildSectionHeader('Cash Flow'),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 180,
                              child: _buildCashFlowChart(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
  
  Widget _buildOverviewTab(String currencySymbol) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cash flow chart
          _buildSectionHeader('Cash Flow'),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: _buildCashFlowChart(),
          ),
          const SizedBox(height: 24),
          
          // Spending breakdown
          _buildSectionHeader('Spending Breakdown'),
          const SizedBox(height: 8),
          SizedBox(
            height: 180, // Reduced height to match other charts
            child: _buildPieChart(_categoryExpenses, currencySymbol),
          ),
        ],
      ),
    );
  }
  
  Widget _buildExpensesTab(String currencySymbol) {
    // Sort categories by amount
    final sortedCategories = _categoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final totalExpenses = _categoryExpenses.values.fold(0.0, (sum, amount) => sum + amount);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Expense Categories'),
          const SizedBox(height: 16),
          
          // Pie chart
          SizedBox(
            height: 180,
            child: _buildPieChart(_categoryExpenses, currencySymbol),
          ),
          const SizedBox(height: 24),
          
          // Category list
          ...sortedCategories.map((entry) {
            final percentage = totalExpenses > 0 ? (entry.value / totalExpenses) * 100 : 0;
            return _buildCategoryItem(
              entry.key, 
              entry.value, 
              percentage.toDouble(), 
              currencySymbol,
              AppColors.categoryRed,
            );
          }),
        ],
      ),
    );
  }
  
  Widget _buildIncomeTab(String currencySymbol) {
    // Sort categories by amount
    final sortedCategories = _categoryIncome.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final totalIncome = _categoryIncome.values.fold(0.0, (sum, amount) => sum + amount);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Income Sources'),
          const SizedBox(height: 16),
          
          // Pie chart
          SizedBox(
            height: 180,
            child: _buildPieChart(_categoryIncome, currencySymbol),
          ),
          const SizedBox(height: 24),
          
          // Category list
          ...sortedCategories.map((entry) {
            final percentage = totalIncome > 0 ? (entry.value / totalIncome) * 100 : 0;
            return _buildCategoryItem(
              entry.key, 
              entry.value, 
              percentage.toDouble(), 
              currencySymbol,
              AppColors.primaryGreen,
            );
          }),
        ],
      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }
  
  Widget _buildStatCard(String title, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCashFlowChart() {
    return _incomeSpots.isEmpty && _expenseSpots.isEmpty
        ? const Center(child: Text('No transaction data available'))
        : LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      // Only show a few dates to avoid crowding
                      if (value.toInt() % (_incomeSpots.length ~/ 5 + 1) != 0) {
                        return const SizedBox.shrink();
                      }
                      
                      final now = DateTime.now();
                      final startDate = _getStartDate();
                      final date = startDate.add(Duration(days: value.toInt()));
                      
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          DateFormat('MM/dd').format(date),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: (_incomeSpots.length - 1).toDouble(),
              minY: 0,
              maxY: _maxY,
              lineTouchData: const LineTouchData(enabled: true, handleBuiltInTouches: true),
              lineBarsData: [
                // Income line
                LineChartBarData(
                  spots: _incomeSpots,
                  isCurved: false, // Changed to false for better performance
                  color: AppColors.primaryGreen,
                  barWidth: 2, // Reduced width for better performance
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.primaryGreen.withOpacity(0.1), // Reduced opacity for better performance
                    applyCutOffY: true, // Improved rendering
                    cutOffY: 0,
                    // Removed spots line for better performance
                  ),
                ),
                // Expense line
                LineChartBarData(
                  spots: _expenseSpots,
                  isCurved: false, // Changed to false for better performance
                  color: AppColors.categoryRed,
                  barWidth: 2, // Reduced width for better performance
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.categoryRed.withOpacity(0.1), // Reduced opacity
                    applyCutOffY: true, // Improved rendering
                    cutOffY: 0,
                    // Removed spots line for better performance
                  ),
                ),
              ],
            ),
          );
  }
  
  Widget _buildPieChart(Map<String, double> data, String currencySymbol) {
    if (data.isEmpty) {
      return const Center(child: Text('No data available'));
    }
    
    final total = data.values.fold(0.0, (sum, amount) => sum + amount);
    
    // Generate sections
    final sections = <PieChartSectionData>[];
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
      Colors.cyan,
      Colors.indigo,
    ];
    
    int colorIndex = 0;
    data.forEach((category, amount) {
      final percentage = (amount / total) * 100;
      // Only add sections that are at least 1% of the total to improve performance
      if (percentage >= 1.0) {
        sections.add(
          PieChartSectionData(
            color: colors[colorIndex % colors.length],
            value: amount,
            title: percentage >= 5.0 ? '${percentage.toStringAsFixed(0)}%' : '', // Only show labels for larger sections
            radius: 80, // Smaller radius for better performance
            titleStyle: const TextStyle(
              fontSize: 10, // Smaller font
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      }
      colorIndex++;
    });
    
    return Row(
      children: [
        // Pie chart
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              startDegreeOffset: -90,
            ),
          ),
        ),
        
        // Legend - simplified for better performance
        Expanded(
          flex: 2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(
              // Limit to top 3 entries for better performance
              data.length > 3 ? 3 : data.length,
              (index) {
                // Sort entries by value to show the most significant ones
                final entries = data.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                final entry = entries[index];
                final color = colors[index % colors.length];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2), // Reduced padding
                  child: Row(
                    children: [
                      Container(
                        width: 10, // Smaller indicator
                        height: 10, // Smaller indicator
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6), // Reduced spacing
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontSize: 10), // Smaller font
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1, // Ensure single line
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildCategoryItem(String category, double amount, double percentage, String currencySymbol, Color color) {
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final categoryIcon = categoryProvider.getCategoryIcon(category);
    final categoryColor = categoryProvider.getCategoryColor(category);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Category icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: categoryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              categoryIcon,
              color: categoryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          
          // Category name
          Expanded(
            child: Text(
              category,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          // Amount and percentage
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$currencySymbol${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  double _calculateTotalIncome(TransactionProvider provider) {
    final transactions = _getFilteredTransactions(provider);
    return transactions
        .where((t) => t.type.toLowerCase() == 'income')
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double _calculateTotalExpenses(TransactionProvider provider) {
    final transactions = _getFilteredTransactions(provider);
    return transactions
        .where((t) => t.type.toLowerCase() == 'expense')
        .fold(0.0, (sum, t) => sum + t.amount);
  }
}
