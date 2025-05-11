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
        notes TEXT,
        FOREIGN KEY (category) REFERENCES categories(name)
      )
    ''');
    
    // Create table for recurring transactions (added in v2)
    if (version >= 2) {
      await _createRecurringTransactionsTable(db);
    }

    await _initializeDefaultCategories(db);
  }
  
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('Upgrading database from version $oldVersion to $newVersion');
    
    if (oldVersion < 2 && newVersion >= 2) {
      // Add notes column to transactions table
      await db.execute('ALTER TABLE transactions ADD COLUMN notes TEXT');
      
      // Create recurring transactions table
      await _createRecurringTransactionsTable(db);
    }
    
    // Add more migration paths here for future versions
  }
  
  Future<void> _createRecurringTransactionsTable(Database db) async {
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
        is_active INTEGER NOT NULL DEFAULT 1,
        last_processed TEXT,
        FOREIGN KEY (category) REFERENCES categories(name)
      )
    ''');
  }

  static const _defaultCategories = [
    {
      'name': 'Salary',
      'description': 'Regular income',
      'icon': 'work',
      'isExpense': 0
    },
    {
      'name': 'Freelance',
      'description': 'Freelance income',
      'icon': 'computer',
      'isExpense': 0
    },
    {
      'name': 'Investments',
      'description': 'Investment returns',
      'icon': 'trending_up',
      'isExpense': 0
    },
    {
      'name': 'Food',
      'description': 'Food and dining',
      'icon': 'restaurant',
      'isExpense': 1
    },
    {
      'name': 'Transportation',
      'description': 'Transport expenses',
      'icon': 'directions_car',
      'isExpense': 1
    },
    {
      'name': 'Shopping',
      'description': 'Retail purchases',
      'icon': 'shopping_cart',
      'isExpense': 1
    },
    {
      'name': 'Bills',
      'description': 'Regular bills',
      'icon': 'receipt_long',
      'isExpense': 1
    },
    {
      'name': 'Healthcare',
      'description': 'Medical expenses',
      'icon': 'medical_services',
      'isExpense': 1
    },
    {
      'name': 'Entertainment',
      'description': 'Entertainment expenses',
      'icon': 'movie',
      'isExpense': 1
    },
    {
      'name': 'Education',
      'description': 'Education expenses',
      'icon': 'school',
      'isExpense': 1
    },
    {
      'name': 'Gifts',
      'description': 'Gifts given',
      'icon': 'card_giftcard',
      'isExpense': 1
    }
  ];

  Future<void> _initializeDefaultCategories(Database db) async {
    for (final category in _defaultCategories) {
      await db.insert('categories', category,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // Transaction methods
  Future<int> addTransaction(custom.Transaction transaction) async {
    // Validate transaction data
    if (transaction.amount <= 0) {
      throw DatabaseException('Transaction amount must be greater than zero');
    }
    
    if (transaction.description.isEmpty) {
      throw DatabaseException('Transaction description cannot be empty');
    }
    
    if (!['income', 'expense'].contains(transaction.type.toLowerCase())) {
      throw DatabaseException('Transaction type must be income or expense');
    }
    
    Database db = await openDatabase(
    join(await getDatabasesPath(), 'wealthwarden.db'),
    version: _databaseVersion,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
    onConfigure: _onConfigure,
  );
    final map = transaction.toMap();
    map.remove('id'); // Remove id for auto-increment
    
    try {
      // Verify the category exists
      final categoryExists = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM categories WHERE name = ?',
        [transaction.category]
      )) ?? 0;
      
      if (categoryExists == 0) {
        throw DatabaseException('Category ${transaction.category} does not exist');
      }
      
      return await db.insert('transactions', map);
    } catch (e) {
      throw DatabaseException('Failed to add transaction: ${e.toString()}');
    }
  }

  Future<bool> updateTransaction(custom.Transaction transaction) async {
    // Validate transaction data
    if (transaction.id == null) {
      throw DatabaseException('Transaction ID must be provided for update');
    }
    
    if (transaction.amount <= 0) {
      throw DatabaseException('Transaction amount must be greater than zero');
    }
    
    if (transaction.description.isEmpty) {
      throw DatabaseException('Transaction description cannot be empty');
    }
    
    if (!['income', 'expense'].contains(transaction.type.toLowerCase())) {
      throw DatabaseException('Transaction type must be income or expense');
    }
    
    Database db = await openDatabase(
    join(await getDatabasesPath(), 'wealthwarden.db'),
    version: _databaseVersion,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
    onConfigure: _onConfigure,
  );
    try {
      // Verify the category exists
      final categoryExists = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM categories WHERE name = ?',
        [transaction.category]
      )) ?? 0;
      
      if (categoryExists == 0) {
        throw DatabaseException('Category ${transaction.category} does not exist');
      }
      
      final count = await db.update(
        'transactions',
        transaction.toMap(),
        where: 'id = ?',
        whereArgs: [transaction.id],
      );
      return count > 0;
    } catch (e) {
      throw DatabaseException('Failed to update transaction: ${e.toString()}');
    }
  }

  Future<bool> deleteTransaction(int id) async {
    Database db = await openDatabase(
    join(await getDatabasesPath(), 'wealthwarden.db'),
    version: _databaseVersion,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
    onConfigure: _onConfigure,
  );
    try {
      final count = await db.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      );
      return count > 0;
    } catch (e) {
      throw DatabaseException('Failed to delete transaction: ${e.toString()}');
    }
  }

  Future<List<custom.Transaction>> getAllTransactions({int? limit, int? offset}) async {
    Database db = await openDatabase(
    join(await getDatabasesPath(), 'wealthwarden.db'),
    version: _databaseVersion,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
    onConfigure: _onConfigure,
  );
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'transactions',
        orderBy: 'date DESC',
        limit: limit,
        offset: offset,
      );
      
      return maps.map((map) => custom.Transaction.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get transactions: ${e.toString()}');
    }
  }

  Future<List<custom.Transaction>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? type,
    String? category,
    int? limit,
    int? offset,
  }) async {
    Database db = await openDatabase(
    join(await getDatabasesPath(), 'wealthwarden.db'),
    version: _databaseVersion,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
    onConfigure: _onConfigure,
  );
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

      if (type != null) {
        whereConditions.add('type = ?');
        whereArgs.add(type.toLowerCase());
      }

      if (category != null) {
        whereConditions.add('category = ?');
        whereArgs.add(category);
      }

      final String whereClause = whereConditions.isEmpty 
          ? '' 
          : 'WHERE ${whereConditions.join(' AND ')}';
          
      final String limitClause = limit != null ? ' LIMIT $limit' : '';
      final String offsetClause = offset != null ? ' OFFSET $offset' : '';

      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT * FROM transactions 
        $whereClause 
        ORDER BY date DESC
        $limitClause
        $offsetClause
      ''', whereArgs);

      return maps.map((map) => custom.Transaction.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get transactions: ${e.toString()}');
    }
  }
  
  // Get transaction count for pagination
  Future<int> getTransactionCount({
    DateTime? startDate,
    DateTime? endDate,
    String? type,
    String? category,
  }) async {
    Database db = await openDatabase(
    join(await getDatabasesPath(), 'wealthwarden.db'),
    version: _databaseVersion,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
    onConfigure: _onConfigure,
  );
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

      if (type != null) {
        whereConditions.add('type = ?');
        whereArgs.add(type.toLowerCase());
      }

      if (category != null) {
        whereConditions.add('category = ?');
        whereArgs.add(category);
      }

      final String whereClause = whereConditions.isEmpty 
          ? '' 
          : 'WHERE ${whereConditions.join(' AND ')}';

      final result = await db.rawQuery('''
        SELECT COUNT(*) as count FROM transactions 
        $whereClause
      ''', whereArgs);

      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      throw DatabaseException('Failed to get transaction count: ${e.toString()}');
    }
  }

  // Category methods
  Future<List<model.Category>> getCategories({bool? isExpense}) async {
    Database db = await openDatabase(
    join(await getDatabasesPath(), 'wealthwarden.db'),
    version: _databaseVersion,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
    onConfigure: _onConfigure,
  );
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'categories',
        where: isExpense != null ? 'isExpense = ?' : null,
        whereArgs: isExpense != null ? [isExpense ? 1 : 0] : null,
        orderBy: 'name ASC',
      );
      return maps.map((map) => model.Category.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get categories: ${e.toString()}');
    }
  }

  Future<bool> addCategory(model.Category category) async {
    // Validate category data
    if (category.name.isEmpty) {
      throw DatabaseException('Category name cannot be empty');
    }
    
    if (category.icon.isEmpty) {
      throw DatabaseException('Category icon cannot be empty');
    }
    
    Database db = await openDatabase(
    join(await getDatabasesPath(), 'wealthwarden.db'),
    version: _databaseVersion,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
    onConfigure: _onConfigure,
  );
    try {
      // Check if category with same name already exists
      final categoryExists = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM categories WHERE name = ?',
        [category.name]
      )) ?? 0;
      
      if (categoryExists > 0) {
        throw DatabaseException('Category with name ${category.name} already exists');
      }
      
      final map = category.toMap();
      map.remove('id'); // Remove id for auto-increment
      await db.insert('categories', map);
      return true;
    } catch (e) {
      throw DatabaseException('Failed to add category: ${e.toString()}');
    }
  }

  Future<bool> updateCategory(model.Category category) async {
    Database db = await openDatabase(
    join(await getDatabasesPath(), 'wealthwarden.db'),
    version: _databaseVersion,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
    onConfigure: _onConfigure,
  );
    try {
      final count = await db.update(
        'categories',
        category.toMap(),
        where: 'id = ?',
        whereArgs: [category.id],
      );
      return count > 0;
    } catch (e) {
      throw DatabaseException('Failed to update category: ${e.toString()}');
    }
  }

  Future<bool> deleteCategory(int id) async {
    Database db = await openDatabase(
    join(await getDatabasesPath(), 'wealthwarden.db'),
    version: _databaseVersion,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
    onConfigure: _onConfigure,
  );
    try {
      final count = await db.delete(
        'categories',
        where: 'id = ?',
        whereArgs: [id],
      );
      return count > 0;
    } catch (e) {
      throw DatabaseException('Failed to delete category: ${e.toString()}');
    }
  }

  // Add method to refresh categories
  Future<void> refreshCategories() async {
    Database db = await openDatabase(
    join(await getDatabasesPath(), 'wealthwarden.db'),
    version: _databaseVersion,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
    onConfigure: _onConfigure,
  );
    await _initializeDefaultCategories(db);
  }

  Future<Map<String, dynamic>?> getTransaction(int id) async {
    Database db = await openDatabase(
    join(await getDatabasesPath(), 'wealthwarden.db'),
    version: _databaseVersion,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
    onConfigure: _onConfigure,
  );
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isEmpty) {
      return null;
    }
    return maps.first;
  }

  Future<List<model.Category>> _loadCategories() async {
    Database db = await openDatabase(
    join(await getDatabasesPath(), 'wealthwarden.db'),
    version: _databaseVersion,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
    onConfigure: _onConfigure,
  );
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'categories',
        orderBy: 'name ASC',
      );
      return maps.map((map) => model.Category.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Failed to load categories: ${e.toString()}');
    }
  }

  Future<bool> _addCategory(model.Category category) async {
    Database db = await openDatabase(
    join(await getDatabasesPath(), 'wealthwarden.db'),
    version: _databaseVersion,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
    onConfigure: _onConfigure,
  );
    try {
      final map = category.toMap();
      map.remove('id'); // Remove id for auto-increment
      
      await db.insert(
        'categories', 
        map,
        conflictAlgorithm: ConflictAlgorithm.replace
      );
      return true;
    } catch (e) {
      throw DatabaseException('Failed to add category: ${e.toString()}');
    }
  }

  Future<bool> _deleteCategory(int id) async {
    Database db = await openDatabase(
    join(await getDatabasesPath(), 'wealthwarden.db'),
    version: _databaseVersion,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
    onConfigure: _onConfigure,
  );
    try {
      // First check if category is used in any transactions
      final transactionCount = Sqflite.firstIntValue(await db.rawQuery('''
        SELECT COUNT(*) FROM transactions 
        WHERE category IN (SELECT name FROM categories WHERE id = ?)
      ''', [id]));

      if (transactionCount! > 0) {
        throw DatabaseException(
          'Cannot delete category that is used in transactions'
        );
      }

      final count = await db.delete(
        'categories',
        where: 'id = ?',
        whereArgs: [id],
      );
      return count > 0;
    } catch (e) {
      throw DatabaseException('Failed to delete category: ${e.toString()}');
    }
  }
}

class DatabaseException implements Exception {
  final String message;
  DatabaseException(this.message);
  
  @override
  String toString() => message;
}

// Methods for recurring transactions
Future<int> addRecurringTransaction(Map<String, dynamic> transaction) async {
  Database db = await openDatabase(
    join(await getDatabasesPath(), 'wealthwarden.db'),
    version: _databaseVersion,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
    onConfigure: _onConfigure,
  );
  try {
    // Validate required fields
    if (transaction['description'] == null || transaction['description'].isEmpty) {
      throw DatabaseException('Description is required');
    }
    
    if (transaction['amount'] == null || transaction['amount'] <= 0) {
      throw DatabaseException('Amount must be greater than zero');
    }
    
    if (transaction['type'] == null || 
        !['income', 'expense'].contains(transaction['type'].toString().toLowerCase())) {
      throw DatabaseException('Type must be income or expense');
    }
    
    if (transaction['category'] == null || transaction['category'].isEmpty) {
      throw DatabaseException('Category is required');
    }
    
    if (transaction['frequency'] == null || 
        !['daily', 'weekly', 'monthly', 'yearly'].contains(transaction['frequency'].toString().toLowerCase())) {
      throw DatabaseException('Frequency must be daily, weekly, monthly, or yearly');
    }
    
    if (transaction['start_date'] == null) {
      throw DatabaseException('Start date is required');
    }
    
    // Verify the category exists
    final categoryExists = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM categories WHERE name = ?',
      [transaction['category']]
    )) ?? 0;
    
    if (categoryExists == 0) {
      throw DatabaseException('Category ${transaction['category']} does not exist');
    }
    
    return await db.insert('recurring_transactions', transaction);
  } catch (e) {
    throw DatabaseException('Failed to add recurring transaction: ${e.toString()}');
  }
}

Future<bool> updateRecurringTransaction(Map<String, dynamic> transaction) async {
  Database db = await openDatabase(
    join(await getDatabasesPath(), 'wealthwarden.db'),
    version: _databaseVersion,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
    onConfigure: _onConfigure,
  );
  try {
    if (transaction['id'] == null) {
      throw DatabaseException('Transaction ID is required for update');
    }
    
    // Perform the same validations as in addRecurringTransaction
    
    final count = await db.update(
      'recurring_transactions',
      transaction,
      where: 'id = ?',
      whereArgs: [transaction['id']],
    );
    return count > 0;
  } catch (e) {
    throw DatabaseException('Failed to update recurring transaction: ${e.toString()}');
  }
}

Future<bool> deleteRecurringTransaction(int id) async {
  Database db = await openDatabase(
    join(await getDatabasesPath(), 'wealthwarden.db'),
    version: _databaseVersion,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
    onConfigure: _onConfigure,
  );
  try {
    final count = await db.delete(
      'recurring_transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    return count > 0;
  } catch (e) {
    throw DatabaseException('Failed to delete recurring transaction: ${e.toString()}');
  }
}

Future<List<Map<String, dynamic>>> getRecurringTransactions() async {
  Database db = await openDatabase(
    join(await getDatabasesPath(), 'wealthwarden.db'),
    version: _databaseVersion,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
    onConfigure: _onConfigure,
  );
  try {
    return await db.query(
      'recurring_transactions',
      orderBy: 'start_date DESC',
    );
  } catch (e) {
    throw DatabaseException('Failed to get recurring transactions: ${e.toString()}');
  }
}

Future<Map<String, dynamic>?> getRecurringTransaction(int id) async {
  Database db = await openDatabase(
    join(await getDatabasesPath(), 'wealthwarden.db'),
    version: _databaseVersion,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
    onConfigure: _onConfigure,
  );
  try {
    final List<Map<String, dynamic>> result = await db.query(
      'recurring_transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    return result.isNotEmpty ? result.first : null;
  } catch (e) {
    throw DatabaseException('Failed to get recurring transaction: ${e.toString()}');
  }
}

Future<bool> updateRecurringTransactionLastProcessed(int id, DateTime date) async {
  Database db = await openDatabase(
    join(await getDatabasesPath(), 'wealthwarden.db'),
    version: _databaseVersion,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
    onConfigure: _onConfigure,
  );
  try {
    final count = await db.update(
      'recurring_transactions',
      {'last_processed': date.toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    return count > 0;
  } catch (e) {
    throw DatabaseException('Failed to update last processed date: ${e.toString()}');
  }
}