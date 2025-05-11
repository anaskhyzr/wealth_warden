import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
// file_picker temporarily disabled
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import '../db/database_helper.dart';
import '../models/transaction.dart';
import '../models/category.dart' as model;
import '../services/google_drive_service.dart';

class BackupProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final GoogleDriveService _googleDriveService = GoogleDriveService();
  bool _isLoading = false;
  String? _errorMessage;
  String? _lastBackupPath;
  DateTime? _lastBackupDate;
  bool _isGoogleDriveConnected = false;

  // Backup schedule settings
  bool _autoBackupEnabled = false;
  String _backupFrequency = 'weekly'; // daily, weekly, monthly

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get lastBackupPath => _lastBackupPath;
  DateTime? get lastBackupDate => _lastBackupDate;
  bool get isGoogleDriveConnected => _isGoogleDriveConnected;
  String? get lastGoogleDriveBackupDate => _googleDriveService.lastBackupDate;
  GoogleDriveService get googleDriveService => _googleDriveService;
  
  // Backup schedule getters
  bool get autoBackupEnabled => _autoBackupEnabled;
  String get backupFrequency => _backupFrequency;
  
  // Get next scheduled backup date
  DateTime? get nextScheduledBackup {
    if (!_autoBackupEnabled || _lastBackupDate == null) return null;
    
    final lastBackup = _lastBackupDate!;
    switch (_backupFrequency) {
      case 'daily':
        return lastBackup.add(const Duration(days: 1));
      case 'weekly':
        return lastBackup.add(const Duration(days: 7));
      case 'monthly':
        // Approximate a month as 30 days
        return lastBackup.add(const Duration(days: 30));
      default:
        return lastBackup.add(const Duration(days: 7)); // Default to weekly
    }
  }
  
  // Initialize provider
  Future<void> init() async {
    try {
      // Load backup schedule settings
      await loadBackupScheduleSettings();
      
      // Initialize Google Drive
      await initGoogleDrive();
      
      // Load last backup info
      final prefs = await SharedPreferences.getInstance();
      final lastBackupDateStr = prefs.getString('last_backup_date');
      if (lastBackupDateStr != null) {
        _lastBackupDate = DateTime.parse(lastBackupDateStr);
      }
      _lastBackupPath = prefs.getString('last_backup_path');
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to initialize backup provider: ${e.toString()}');
      debugPrint('Error initializing backup provider: $e');
    }
  }
  
  // Initialize Google Drive service
  Future<void> initGoogleDrive() async {
    try {
      await _googleDriveService.init();
      _isGoogleDriveConnected = _googleDriveService.isSignedIn;
      notifyListeners();
    } catch (e) {
      _setError('Failed to initialize Google Drive: ${e.toString()}');
      debugPrint('Error initializing Google Drive: $e');
    }
  }
  
  // Connect to Google Drive
  Future<bool> connectToGoogleDrive() async {
    _setLoading(true);
    _clearError();
    
    try {
      final success = await _googleDriveService.signIn();
      _isGoogleDriveConnected = success;
      notifyListeners();
      return success;
    } catch (e) {
      _setError('Failed to connect to Google Drive: ${e.toString()}');
      debugPrint('Error connecting to Google Drive: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Disconnect from Google Drive
  Future<void> disconnectFromGoogleDrive() async {
    _setLoading(true);
    _clearError();
    
    try {
      await _googleDriveService.signOut();
      _isGoogleDriveConnected = false;
      notifyListeners();
    } catch (e) {
      _setError('Failed to disconnect from Google Drive: ${e.toString()}');
      debugPrint('Error disconnecting from Google Drive: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Create a backup of all data
  Future<bool> createBackup() async {
    _setLoading(true);
    _clearError();
    
    try {
      // Get all data
      final transactions = await _dbHelper.getAllTransactions();
      final categories = await _dbHelper.getCategories();
      
      // Create backup object
      final backupData = {
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'transactions': transactions.map((t) => t.toMap()).toList(),
        'categories': categories.map((c) => c is model.Category ? c.toMap() : {'error': 'Invalid category format'}).toList(),
      };
      
      // Convert to JSON
      final jsonData = jsonEncode(backupData);
      
      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupFile = File(path.join(directory.path, 'wealthwarden_backup_$timestamp.json'));
      await backupFile.writeAsString(jsonData);
      
      _lastBackupPath = backupFile.path;
      _lastBackupDate = DateTime.now();
      
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to create backup: ${e.toString()}');
      debugPrint('Error creating backup: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Restore from backup file
  Future<bool> restoreFromBackup(String backupPath) async {
    _setLoading(true);
    _clearError();
    
    try {
      // Read backup file
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        _setError('Backup file not found');
        return false;
      }
      
      final jsonData = await backupFile.readAsString();
      final backupData = jsonDecode(jsonData) as Map<String, dynamic>;
      
      // Validate backup format
      if (!backupData.containsKey('version') || 
          !backupData.containsKey('transactions') || 
          !backupData.containsKey('categories')) {
        _setError('Invalid backup format');
        return false;
      }
      
      // Clear existing data (optional, could implement merge strategy)
      // This is a simplified approach - in a real app, you might want to confirm with the user
      
      // Restore categories first (due to foreign key constraints)
      final categoriesData = backupData['categories'] as List<dynamic>;
      for (final categoryData in categoriesData) {
        final category = model.Category.fromMap(categoryData as Map<String, dynamic>);
        await _dbHelper.addCategory(category);
      }
      
      // Restore transactions
      final transactionsData = backupData['transactions'] as List<dynamic>;
      for (final transactionData in transactionsData) {
        final transaction = Transaction.fromMap(transactionData as Map<String, dynamic>);
        await _dbHelper.addTransaction(transaction);
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to restore backup: ${e.toString()}');
      debugPrint('Error restoring backup: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Export transactions to Excel (Simple version)
  Future<String?> _exportToExcelSimple() async {
    _setLoading(true);
    _clearError();
    
    try {
      // Get all transactions
      final transactions = await _dbHelper.getAllTransactions();
      
      // Create Excel workbook
      final excel = Excel.createExcel();
      final sheet = excel['Transactions'];
      
      // Add headers
      sheet.appendRow([
        TextCellValue('ID'),
        TextCellValue('Description'),
        TextCellValue('Amount'),
        TextCellValue('Date'),
        TextCellValue('Type'),
        TextCellValue('Category'),
      ]);
      
      // Add transaction data
      for (final transaction in transactions) {
        sheet.appendRow([
          TextCellValue(transaction.id?.toString() ?? ''),
          TextCellValue(transaction.description),
          DoubleCellValue(transaction.amount),
          TextCellValue(transaction.date.toIso8601String()),
          TextCellValue(transaction.type),
          TextCellValue(transaction.category),
        ]);
      }
      
      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final excelFile = File(path.join(directory.path, 'wealthwarden_export_$timestamp.xlsx'));
      
      final excelBytes = excel.save();
      if (excelBytes != null) {
        await excelFile.writeAsBytes(excelBytes);
        
        // Return the file path for sharing
        _lastBackupPath = excelFile.path;
        notifyListeners();
        return excelFile.path;
      } else {
        _setError('Failed to generate Excel file');
        return null;
      }
    } catch (e) {
      _setError('Failed to export to Excel: ${e.toString()}');
      debugPrint('Error exporting to Excel: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Share backup file
  Future<void> shareBackup(String filePath) async {
    try {
      final result = await Share.shareXFiles(
        [XFile(filePath)],
        text: 'WealthWarden Backup',
      );
      
      debugPrint('Share result: ${result.status}');
    } catch (e) {
      _setError('Failed to share backup: ${e.toString()}');
      debugPrint('Error sharing backup: $e');
    }
  }

  // List available backups
  Future<List<String>> listBackups() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final dir = Directory(directory.path);
      
      final List<String> backupFiles = [];
      
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.contains('wealthwarden_backup_') && entity.path.endsWith('.json')) {
          backupFiles.add(entity.path);
        }
      }
      
      return backupFiles;
    } catch (e) {
      _setError('Failed to list backups: ${e.toString()}');
      debugPrint('Error listing backups: $e');
      return [];
    }
  }

  // Delete a backup file
  Future<bool> deleteBackup(String backupPath) async {
    try {
      final file = File(backupPath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      _setError('Failed to delete backup: ${e.toString()}');
      debugPrint('Error deleting backup: $e');
      return false;
    }
  }
  
  // Backup to Google Drive
  Future<bool> backupToGoogleDrive() async {
    _setLoading(true);
    _clearError();
    
    try {
      if (!_isGoogleDriveConnected) {
        final connected = await connectToGoogleDrive();
        if (!connected) {
          _setError('Failed to connect to Google Drive');
          return false;
        }
      }
      
      // Get all data
      final transactions = await _dbHelper.getAllTransactions();
      final categories = await _dbHelper.getCategories();
      
      // Create backup object
      final backupData = {
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'transactions': transactions.map((t) => t.toMap()).toList(),
        'categories': categories.map((c) => c.toMap()).toList(),
      };
      
      // Upload to Google Drive
      final success = await _googleDriveService.uploadBackup(backupData);
      
      if (success) {
        _lastBackupDate = DateTime.now();
        notifyListeners();
      }
      
      return success;
    } catch (e) {
      _setError('Failed to backup to Google Drive: ${e.toString()}');
      debugPrint('Error backing up to Google Drive: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Restore from Google Drive
  Future<bool> restoreFromGoogleDrive() async {
    _setLoading(true);
    _clearError();
    
    try {
      if (!_isGoogleDriveConnected) {
        final connected = await connectToGoogleDrive();
        if (!connected) {
          _setError('Failed to connect to Google Drive');
          return false;
        }
      }
      
      // Download backup data
      final backupData = await _googleDriveService.downloadBackup();
      
      if (backupData == null) {
        _setError('No backup found on Google Drive');
        return false;
      }
      
      // Validate backup format
      if (!backupData.containsKey('version') || 
          !backupData.containsKey('transactions') || 
          !backupData.containsKey('categories')) {
        _setError('Invalid backup format');
        return false;
      }
      
      // Restore categories first (due to foreign key constraints)
      final categoriesData = backupData['categories'] as List<dynamic>;
      for (final categoryData in categoriesData) {
        final category = model.Category.fromMap(categoryData as Map<String, dynamic>);
        await _dbHelper.addCategory(category);
      }
      
      // Restore transactions
      final transactionsData = backupData['transactions'] as List<dynamic>;
      for (final transactionData in transactionsData) {
        final transaction = Transaction.fromMap(transactionData as Map<String, dynamic>);
        await _dbHelper.addTransaction(transaction);
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to restore from Google Drive: ${e.toString()}');
      debugPrint('Error restoring from Google Drive: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Import from Excel file
  Future<bool> importFromExcel(String filePath) async {
    _setLoading(true);
    _clearError();
    
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _setError('Excel file not found');
        return false;
      }
      
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      
      if (!excel.tables.containsKey('Transactions')) {
        _setError('Excel file does not contain Transactions sheet');
        return false;
      }
      
      final sheet = excel.tables['Transactions']!;
      final rows = sheet.rows;
      
      if (rows.isEmpty || rows.length < 2) {
        _setError('Excel file does not contain any transaction data');
        return false;
      }
      
      // Skip header row
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        
        if (row.length < 6) continue; // Skip invalid rows
        
        final description = row[1]?.value?.toString() ?? '';
        final amountStr = row[2]?.value?.toString() ?? '0';
        final dateStr = row[3]?.value?.toString() ?? DateTime.now().toIso8601String();
        final type = row[4]?.value?.toString() ?? 'expense';
        final category = row[5]?.value?.toString() ?? 'Other';
        
        double amount = 0;
        try {
          amount = double.parse(amountStr);
        } catch (e) {
          debugPrint('Invalid amount format: $amountStr');
          continue;
        }
        
        DateTime date = DateTime.now();
        try {
          date = DateTime.parse(dateStr);
        } catch (e) {
          debugPrint('Invalid date format: $dateStr');
        }
        
        final transaction = Transaction(
          description: description,
          amount: amount,
          date: date,
          type: type,
          category: category,
        );
        
        await _dbHelper.addTransaction(transaction);
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to import from Excel: ${e.toString()}');
      debugPrint('Error importing from Excel: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Export data to Excel file
  Future<String?> exportToExcel() async {
    _setLoading(true);
    _clearError();
    
    try {
      // Get all data
      final transactions = await _dbHelper.getAllTransactions();
      final categories = await _dbHelper.getCategories();
      
      // Create Excel file
      final excel = Excel.createExcel();
      
      // Remove default sheet
      excel.delete('Sheet1');
      
      // Create transactions sheet
      final transactionsSheet = excel['Transactions'];
      
      // Add header row
      transactionsSheet.appendRow([
        TextCellValue('ID'),
        TextCellValue('Description'),
        TextCellValue('Amount'),
        TextCellValue('Date'),
        TextCellValue('Type'),
        TextCellValue('Category'),
      ]);
      
      // Add transaction rows
      for (final transaction in transactions) {
        transactionsSheet.appendRow([
          TextCellValue(transaction.id?.toString() ?? ''),
          TextCellValue(transaction.description),
          TextCellValue(transaction.amount.toString()),
          TextCellValue(transaction.date.toIso8601String()),
          TextCellValue(transaction.type),
          TextCellValue(transaction.category),
        ]);
      }
      
      // Create categories sheet
      final categoriesSheet = excel['Categories'];
      
      // Add header row
      categoriesSheet.appendRow([
        TextCellValue('ID'),
        TextCellValue('Name'),
        TextCellValue('Description'),
        TextCellValue('Icon'),
        TextCellValue('IsExpense'),
      ]);
      
      // Add category rows
      for (final category in categories) {
        categoriesSheet.appendRow([
          TextCellValue(category.id?.toString() ?? ''),
          TextCellValue(category.name),
          TextCellValue(category.description),
          TextCellValue(category.icon),
          TextCellValue(category.isExpense ? '1' : '0'),
        ]);
      }
      
      // Save Excel file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/wealthwarden_export_$timestamp.xlsx';
      
      final file = File(filePath);
      final bytes = excel.encode();
      if (bytes != null) {
        await file.writeAsBytes(bytes);
        return filePath;
      } else {
        _setError('Failed to encode Excel file');
        return null;
      }
    } catch (e) {
      _setError('Failed to export to Excel: ${e.toString()}');
      debugPrint('Error exporting to Excel: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }
  
  // Share a file
  Future<void> shareFile(String filePath) async {
    try {
      if (filePath.isNotEmpty) {
        await Share.shareXFiles([XFile(filePath)], text: 'WealthWarden Export');
      } else {
        _setError('Invalid file path');
      }
    } catch (e) {
      _setError('Failed to share file: ${e.toString()}');
      debugPrint('Error sharing file: $e');
    }
  }

  // Set auto backup enabled/disabled
  Future<void> setAutoBackupEnabled(bool enabled) async {
    _autoBackupEnabled = enabled;
    
    // Save setting to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_backup_enabled', enabled);
    
    notifyListeners();
  }
  
  // Set backup frequency
  Future<void> setBackupFrequency(String frequency) async {
    if (!['daily', 'weekly', 'monthly'].contains(frequency)) {
      throw Exception('Invalid backup frequency: $frequency');
    }
    
    _backupFrequency = frequency;
    
    // Save setting to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backup_frequency', frequency);
    
    notifyListeners();
  }
  
  // Load backup schedule settings
  Future<void> loadBackupScheduleSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _autoBackupEnabled = prefs.getBool('auto_backup_enabled') ?? false;
    _backupFrequency = prefs.getString('backup_frequency') ?? 'weekly';
    
    // Check if a backup is due
    if (_autoBackupEnabled && _lastBackupDate != null) {
      final now = DateTime.now();
      final nextBackup = nextScheduledBackup;
      
      if (nextBackup != null && now.isAfter(nextBackup)) {
        // A backup is due, perform it automatically
        if (_isGoogleDriveConnected) {
          backupToGoogleDrive();
        } else {
          createBackup();
        }
      }
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
    notifyListeners();
  }
}
