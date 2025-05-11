import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
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
      final recurringTransactions = await _dbHelper.getRecurringTransactions();
      
      // Create backup data map
      final backupData = {
        'transactions': transactions.map((t) => t.toMap()).toList(),
        'categories': categories.map((c) => c.toMap()).toList(),
        'recurringTransactions': recurringTransactions, // Already maps, no need to call toMap()
        'timestamp': DateTime.now().toIso8601String(),
        'version': '1.0.0', // Add version info for future compatibility
      };
      
      // Convert to JSON
      final jsonData = jsonEncode(backupData);
      
      // Get backup directory
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/backups');
      
      // Create backups directory if it doesn't exist
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      
      // Create a user-friendly backup filename with date and time
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final timeStr = '${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}';
      final backupPath = '${backupDir.path}/WealthWarden_Backup_${dateStr}_${timeStr}.json';
      
      // Write backup file
      final file = File(backupPath);
      await file.writeAsString(jsonData);
      
      // Update last backup info
      _lastBackupPath = backupPath;
      _lastBackupDate = DateTime.now();
      
      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_backup_path', backupPath);
      await prefs.setString('last_backup_date', _lastBackupDate!.toIso8601String());
      
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
  
  // Create a local backup and share it
  Future<String?> createAndShareLocalBackup() async {
    _setLoading(true);
    _clearError();
    
    try {
      // Create the backup
      final success = await createBackup();
      
      if (!success || _lastBackupPath == null) {
        _setError('Failed to create local backup');
        return null;
      }
      
      // Copy the backup to a more user-friendly location
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'wealthwarden_backup_$timestamp.ww';
      final sharePath = '${directory.path}/$fileName';
      
      // Copy the file with a more user-friendly extension
      final originalFile = File(_lastBackupPath!);
      final shareFile = await originalFile.copy(sharePath);
      
      return shareFile.path;
    } catch (e) {
      _setError('Failed to create local backup: ${e.toString()}');
      debugPrint('Error creating local backup: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }
  
  // Get a list of local backups
  Future<List<Map<String, dynamic>>> getLocalBackups() async {
    _setLoading(true);
    _clearError();
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/backups');
      
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
        return [];
      }
      
      final files = await backupDir.list().toList();
      final backups = <Map<String, dynamic>>[];
      
      for (final file in files) {
        if (file is File && file.path.endsWith('.json')) {
          final fileName = path.basename(file.path);
          final fileStat = await file.stat();
          final fileSize = fileStat.size;
          
          // Try to parse date from filename
          DateTime? date;
          try {
            final datePart = fileName.split('_').first;
            date = DateTime.parse(datePart);
          } catch (e) {
            // Use file modification time if date parsing fails
            date = fileStat.modified;
          }
          
          backups.add({
            'path': file.path,
            'name': fileName,
            'size': fileSize,
            'date': date,
          });
        }
      }
      
      // Sort by date, newest first
      backups.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
      
      return backups;
    } catch (e) {
      _setError('Failed to get local backups: ${e.toString()}');
      debugPrint('Error getting local backups: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }
  
  // Get available backup files as a list of paths
  Future<List<String>> getAvailableBackupFiles() async {
    try {
      final backups = await getLocalBackups();
      return backups.map((backup) => backup['path'] as String).toList();
    } catch (e) {
      _setError('Failed to get available backup files: ${e.toString()}');
      debugPrint('Error getting available backup files: $e');
      return [];
    }
  }
  
  // Delete a local backup file
  Future<bool> deleteLocalBackup(String backupPath) async {
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
      
      // Get database instance
      final db = await _dbHelper.database;
      
      // Begin transaction for atomicity
      await db.transaction((txn) async {
        // Clear existing data first
        await txn.delete('transactions');
        await txn.delete('categories');
        if (backupData.containsKey('recurringTransactions')) {
          await txn.delete('recurring_transactions');
        }
        
        // Restore categories first (due to foreign key constraints)
        final categoriesData = backupData['categories'] as List<dynamic>;
        for (final categoryData in categoriesData) {
          final category = model.Category.fromMap(categoryData as Map<String, dynamic>);
          // Use transaction object for all operations
          await txn.insert('categories', category.toMap());
        }
        
        // Restore transactions
        final transactionsData = backupData['transactions'] as List<dynamic>;
        for (final transactionData in transactionsData) {
          final transaction = Transaction.fromMap(transactionData as Map<String, dynamic>);
          // Use transaction object for all operations
          await txn.insert('transactions', transaction.toMap());
        }
        
        // Restore recurring transactions if available
        if (backupData.containsKey('recurringTransactions')) {
          final recurringTransactionsData = backupData['recurringTransactions'] as List<dynamic>;
          for (final recurringTransactionData in recurringTransactionsData) {
            // Use transaction object for all operations
            await txn.insert('recurring_transactions', recurringTransactionData as Map<String, dynamic>);
          }
        }
      });
      
      // Update last backup info
      _lastBackupPath = backupPath;
      _lastBackupDate = DateTime.now();
      
      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_backup_path', backupPath);
      await prefs.setString('last_backup_date', _lastBackupDate!.toIso8601String());
      
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
