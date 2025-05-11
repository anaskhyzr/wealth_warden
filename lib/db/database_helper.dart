import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/category.dart' as model;
import '../models/transaction.dart' as custom;

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  
  // Current database version - increment this when schema changes
  static const int _databaseVersion = 2;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'wealthwarden.db');

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    debugPrint('Creating database at version $version');
    
    // Create tables with proper foreign key constraints
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        icon TEXT NOT NULL,
        isExpense INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
        category TEXT NOT NULL,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE recurring_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
        category TEXT NOT NULL,
        frequency TEXT NOT NULL CHECK(frequency IN ('daily', 'weekly', 'monthly', 'yearly')),
        start_date TEXT NOT NULL,
        end_date TEXT,
        last_processed TEXT,
        notes TEXT
      )
    ''');
    
    // Initialize with default categories
    await _initializeDefaultCategories(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('Upgrading database from version $oldVersion to $newVersion');
    
    if (oldVersion < 2) {
      // Add notes column to transactions table if upgrading from version 1
      await db.execute('ALTER TABLE transactions ADD COLUMN notes TEXT');
      
      // Create recurring_transactions table if it doesn't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS recurring_transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          description TEXT NOT NULL,
          amount REAL NOT NULL,
          type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
          category TEXT NOT NULL,
          frequency TEXT NOT NULL CHECK(frequency IN ('daily', 'weekly', 'monthly', 'yearly')),
          start_date TEXT NOT NULL,
          end_date TEXT,
          last_processed TEXT,
          notes TEXT
        )
      ''');
    }
  }

  Future<void> _initializeDefaultCategories(Database db) async {
    final defaultExpenseCategories = [
      {'name': 'Food', 'description': 'Groceries, restaurants, etc.', 'icon': '0xe25a', 'isExpense': 1},
      {'name': 'Transportation', 'description': 'Public transport, fuel, etc.', 'icon': '0xe1d5', 'isExpense': 1},
      {'name': 'Housing', 'description': 'Rent, utilities, etc.', 'icon': '0xe1ad', 'isExpense': 1},
      {'name': 'Entertainment', 'description': 'Movies, games, etc.', 'icon': '0xe333', 'isExpense': 1},
      {'name': 'Shopping', 'description': 'Clothes, electronics, etc.', 'icon': '0xe59c', 'isExpense': 1},
      {'name': 'Health', 'description': 'Medicine, doctor visits, etc.', 'icon': '0xe3f3', 'isExpense': 1},
      {'name': 'Education', 'description': 'Books, courses, etc.', 'icon': '0xe80c', 'isExpense': 1},
      {'name': 'Other', 'description': 'Miscellaneous expenses', 'icon': '0xe5d3', 'isExpense': 1},
    ];
    
    final defaultIncomeCategories = [
      {'name': 'Salary', 'description': 'Regular income from job', 'icon': '0xe63e', 'isExpense': 0},
      {'name': 'Freelance', 'description': 'Income from freelance work', 'icon': '0xf11c', 'isExpense': 0},
      {'name': 'Investment', 'description': 'Returns from investments', 'icon': '0xe624', 'isExpense': 0},
      {'name': 'Gift', 'description': 'Money received as gift', 'icon': '0xe8f6', 'isExpense': 0},
      {'name': 'Other Income', 'description': 'Other sources of income', 'icon': '0xe5d3', 'isExpense': 0},
    ];
    
    // Insert default categories
    for (var category in defaultExpenseCategories) {
      await db.insert('categories', category, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    
    for (var category in defaultIncomeCategories) {
      await db.insert('categories', category, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // Transaction methods
  Future<int> addTransaction(custom.Transaction transaction) async {
    // Validate transaction data
    if (transaction.description.isEmpty) {
      throw Exception('Transaction description cannot be empty');
    }
    
    if (transaction.amount <= 0) {
      throw Exception('Transaction amount must be greater than zero');
    }
    
    if (!['income', 'expense'].contains(transaction.type.toLowerCase())) {
      throw Exception('Transaction type must be income or expense');
    }
    
    final db = await database;
    final map = transaction.toMap();
    map.remove('id'); // Remove id for auto-increment
    
    return await db.insert('transactions', map);
  }

  Future<bool> updateTransaction(custom.Transaction transaction) async {
    // Validate transaction data
    if (transaction.id == null) {
      throw Exception('Transaction ID is required for update');
    }
    
    if (transaction.description.isEmpty) {
      throw Exception('Transaction description cannot be empty');
    }
    
    if (transaction.amount <= 0) {
      throw Exception('Transaction amount must be greater than zero');
    }
    
    if (!['income', 'expense'].contains(transaction.type.toLowerCase())) {
      throw Exception('Transaction type must be income or expense');
    }
    
    final db = await database;
    try {
      // Verify the category exists
      final categoryExists = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM categories WHERE name = ?',
        [transaction.category]
      )) ?? 0;
      
      if (categoryExists == 0) {
        throw Exception('Category ${transaction.category} does not exist');
      }
      
      final count = await db.update(
        'transactions',
        transaction.toMap(),
        where: 'id = ?',
        whereArgs: [transaction.id],
      );
      return count > 0;
    } catch (e) {
      throw Exception('Failed to update transaction: ${e.toString()}');
    }
  }

  Future<bool> deleteTransaction(int id) async {
    final db = await database;
    try {
      final count = await db.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      );
      return count > 0;
    } catch (e) {
      throw Exception('Failed to delete transaction: ${e.toString()}');
    }
  }

  Future<List<custom.Transaction>> getAllTransactions({int? limit, int? offset}) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'transactions',
        orderBy: 'date DESC',
        limit: limit,
        offset: offset,
      );
      
      return maps.map((map) => custom.Transaction.fromMap(map)).toList();
    } catch (e) {
      throw Exception('Failed to get transactions: ${e.toString()}');
    }
  }

  Future<List<custom.Transaction>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    try {
      List<String> whereConditions = [];
      List<dynamic> whereArgs = [];
      
      if (startDate != null) {
        whereConditions.add('date >= ?');
        whereArgs.add(startDate.toIso8601String());
      }
      
      if (endDate != null) {
        whereConditions.add('date <= ?');
        whereArgs.add(endDate.toIso8601String());
      }
      
      String whereClause = whereConditions.isEmpty ? '' : whereConditions.join(' AND ');
      
      final List<Map<String, dynamic>> maps = await db.query(
        'transactions',
        where: whereClause.isEmpty ? null : whereClause,
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: 'date DESC',
        limit: limit,
        offset: offset,
      );
      
      return maps.map((map) => custom.Transaction.fromMap(map)).toList();
    } catch (e) {
      throw Exception('Failed to get transactions: ${e.toString()}');
    }
  }

  Future<List<custom.Transaction>> searchTransactions({
    String? query,
    DateTime? startDate,
    DateTime? endDate,
    String? type,
    String? category,
  }) async {
    final db = await database;
    try {
      List<String> whereConditions = [];
      List<dynamic> whereArgs = [];
      
      if (query != null && query.isNotEmpty) {
        whereConditions.add('(description LIKE ? OR notes LIKE ?)');
        whereArgs.add('%$query%');
        whereArgs.add('%$query%');
      }
      
      if (startDate != null) {
        whereConditions.add('date >= ?');
        whereArgs.add(startDate.toIso8601String());
      }
      
      if (endDate != null) {
        whereConditions.add('date <= ?');
        whereArgs.add(endDate.toIso8601String());
      }
      
      if (type != null && type.isNotEmpty) {
        whereConditions.add('type = ?');
        whereArgs.add(type);
      }
      
      if (category != null && category.isNotEmpty) {
        whereConditions.add('category = ?');
        whereArgs.add(category);
      }
      
      String whereClause = whereConditions.isEmpty ? '' : whereConditions.join(' AND ');
      
      final List<Map<String, dynamic>> maps = await db.query(
        'transactions',
        where: whereClause.isEmpty ? null : whereClause,
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: 'date DESC',
      );
      
      return maps.map((map) => custom.Transaction.fromMap(map)).toList();
    } catch (e) {
      throw Exception('Failed to search transactions: ${e.toString()}');
    }
  }

  // Category methods
  Future<List<model.Category>> getCategories({bool? isExpense}) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'categories',
        whereArgs: isExpense != null ? [isExpense ? 1 : 0] : null,
        orderBy: 'name ASC',
      );
      return maps.map((map) => model.Category.fromMap(map)).toList();
    } catch (e) {
      throw Exception('Failed to get categories: ${e.toString()}');
    }
  }

  Future<bool> addCategory(model.Category category) async {
    // Validate category data
    if (category.name.isEmpty) {
      throw Exception('Category name cannot be empty');
    }
    
    if (category.icon.isEmpty) {
      throw Exception('Category icon cannot be empty');
    }
    
    final db = await database;
    try {
      // Check if category with same name already exists
      final categoryExists = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM categories WHERE name = ?',
        [category.name]
      )) ?? 0;
      
      if (categoryExists > 0) {
        throw Exception('Category with name ${category.name} already exists');
      }
      
      final map = category.toMap();
      map.remove('id'); // Remove id for auto-increment
      
      final id = await db.insert('categories', map);
      return id > 0;
    } catch (e) {
      throw Exception('Failed to add category: ${e.toString()}');
    }
  }

  Future<bool> updateCategory(model.Category category) async {
    final db = await database;
    try {
      final count = await db.update(
        'categories',
        category.toMap(),
        where: 'id = ?',
        whereArgs: [category.id],
      );
      return count > 0;
    } catch (e) {
      throw Exception('Failed to update category: ${e.toString()}');
    }
  }

  Future<bool> deleteCategory(int id) async {
    final db = await database;
    try {
      final count = await db.delete(
        'categories',
        where: 'id = ?',
        whereArgs: [id],
      );
      return count > 0;
    } catch (e) {
      throw Exception('Failed to delete category: ${e.toString()}');
    }
  }

  // Add method to refresh categories
  Future<void> refreshCategories() async {
    final db = await database;
    await _initializeDefaultCategories(db);
  }
  
  // Get all recurring transactions
  Future<List<Map<String, dynamic>>> getRecurringTransactions() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'recurring_transactions',
        orderBy: 'start_date DESC',
      );
      return maps;
    } catch (e) {
      debugPrint('Error getting recurring transactions: $e');
      return [];
    }
  }
}
