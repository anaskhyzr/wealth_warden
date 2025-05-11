import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// file_picker temporarily disabled
import 'package:intl/intl.dart';
import '../providers/providers.dart';
import '../utils/app_theme.dart';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _backupsList = [];
  
  @override
  void initState() {
    super.initState();
    _initBackupProvider();
  }
  
  Future<void> _initBackupProvider() async {
    final backupProvider = Provider.of<BackupProvider>(context, listen: false);
    
    setState(() => _isLoading = true);
    
    try {
      await backupProvider.initGoogleDrive();
      if (backupProvider.isGoogleDriveConnected) {
        await _refreshBackupsList();
      }
    } catch (e) {
      debugPrint('Error initializing backup provider: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _refreshBackupsList() async {
    final backupProvider = Provider.of<BackupProvider>(context, listen: false);
    
    setState(() => _isLoading = true);
    
    try {
      if (backupProvider.isGoogleDriveConnected) {
        final googleDriveService = backupProvider.googleDriveService;
        final backups = await googleDriveService.listBackups();
        setState(() => _backupsList = backups);
      }
    } catch (e) {
      debugPrint('Error refreshing backups list: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _connectToGoogleDrive() async {
    final backupProvider = Provider.of<BackupProvider>(context, listen: false);
    
    setState(() => _isLoading = true);
    
    try {
      final success = await backupProvider.connectToGoogleDrive();
      
      if (!mounted) return;
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connected to Google Drive')),
        );
        await _refreshBackupsList();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(backupProvider.errorMessage ?? 'Failed to connect to Google Drive')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _disconnectFromGoogleDrive() async {
    final backupProvider = Provider.of<BackupProvider>(context, listen: false);
    
    setState(() => _isLoading = true);
    
    try {
      await backupProvider.disconnectFromGoogleDrive();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Disconnected from Google Drive')),
      );
      setState(() => _backupsList = []);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _createBackup() async {
    final backupProvider = Provider.of<BackupProvider>(context, listen: false);
    
    setState(() => _isLoading = true);
    
    try {
      final success = await backupProvider.backupToGoogleDrive();
      
      if (!mounted) return;
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup created successfully')),
        );
        await _refreshBackupsList();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(backupProvider.errorMessage ?? 'Failed to create backup')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _restoreBackup() async {
    final backupProvider = Provider.of<BackupProvider>(context, listen: false);
    
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Backup'),
        content: const Text(
          'This will replace all your current data with the backup data. This action cannot be undone. Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirm) return;
    
    setState(() => _isLoading = true);
    
    try {
      final success = await backupProvider.restoreFromGoogleDrive();
      
      if (!mounted) return;
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restored successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(backupProvider.errorMessage ?? 'Failed to restore backup')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _importFromExcel() async {
    final backupProvider = Provider.of<BackupProvider>(context, listen: false);
    
    setState(() => _isLoading = true);
    
    try {
      // Show a message that file_picker is temporarily disabled
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File picking is temporarily disabled. Please use the sample data instead.'),
          duration: Duration(seconds: 5),
        ),
      );
      
      // TODO: Implement alternative file picking method or use sample data
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _exportToExcel() async {
    final backupProvider = Provider.of<BackupProvider>(context, listen: false);
    
    setState(() => _isLoading = true);
    
    try {
      final filePath = await backupProvider.exportToExcel();
      
      if (!mounted) return;
      
      if (filePath != null) {
        final share = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Export Successful'),
            content: Text('Data exported to: $filePath\n\nWould you like to share this file?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Share'),
              ),
            ],
          ),
        ) ?? false;
        
        if (share && filePath != null) {
          await backupProvider.shareFile(filePath);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(backupProvider.errorMessage ?? 'Failed to export data')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final backupProvider = Provider.of<BackupProvider>(context);
    final isConnected = backupProvider.isGoogleDriveConnected;
    final lastBackupDate = backupProvider.lastGoogleDriveBackupDate;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refreshBackupsList,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshBackupsList,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Google Drive Section
                    Card(
                      margin: const EdgeInsets.only(bottom: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      color: AppColors.darkCard,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.cloud,
                                  color: isConnected
                                      ? AppColors.primaryGreen
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 8.0),
                                Text(
                                  'Google Drive',
                                  style: TextStyle(
                                    fontSize: 18.0,
                                    fontWeight: FontWeight.bold,
                                    color: isConnected
                                        ? AppColors.darkTextPrimary
                                        : Colors.grey,
                                  ),
                                ),
                                const Spacer(),
                                Switch(
                                  value: isConnected,
                                  onChanged: (value) {
                                    if (value) {
                                      _connectToGoogleDrive();
                                    } else {
                                      _disconnectFromGoogleDrive();
                                    }
                                  },
                                  activeColor: AppColors.primaryGreen,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8.0),
                            Text(
                              isConnected
                                  ? 'Connected to Google Drive'
                                  : 'Connect to Google Drive to backup your data',
                              style: TextStyle(
                                color: AppColors.darkTextSecondary,
                              ),
                            ),
                            if (isConnected && lastBackupDate != null) ...[
                              const SizedBox(height: 8.0),
                              Text(
                                'Last backup: ${DateFormat.yMMMd().add_jm().format(DateTime.parse(lastBackupDate))}',
                                style: TextStyle(
                                  color: AppColors.darkTextSecondary,
                                  fontSize: 12.0,
                                ),
                              ),
                            ],
                            if (isConnected) ...[
                              const SizedBox(height: 16.0),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _createBackup,
                                      icon: const Icon(Icons.backup),
                                      label: const Text('Backup'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primaryGreen,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8.0),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _backupsList.isNotEmpty
                                          ? _restoreBackup
                                          : null,
                                      icon: const Icon(Icons.restore),
                                      label: const Text('Restore'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.darkBackground,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    
                    // Backup Schedule Section
                    Card(
                      margin: const EdgeInsets.only(bottom: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      color: AppColors.darkCard,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.schedule),
                                const SizedBox(width: 8.0),
                                const Text(
                                  'Automatic Backup',
                                  style: TextStyle(
                                    fontSize: 18.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Switch(
                                  value: backupProvider.autoBackupEnabled,
                                  onChanged: (value) async {
                                    try {
                                      await backupProvider.setAutoBackupEnabled(value);
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error: ${e.toString()}')),
                                      );
                                    }
                                  },
                                  activeColor: AppColors.primaryGreen,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8.0),
                            const Text(
                              'Schedule automatic backups to keep your data safe',
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                            if (backupProvider.autoBackupEnabled) ...[  
                              const SizedBox(height: 16.0),
                              const Text(
                                'Backup Frequency',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8.0),
                              DropdownButtonFormField<String>(
                                value: backupProvider.backupFrequency,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 'daily',
                                    child: const Text('Daily'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'weekly',
                                    child: const Text('Weekly'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'monthly',
                                    child: const Text('Monthly'),
                                  ),
                                ],
                                onChanged: (value) async {
                                  if (value != null) {
                                    try {
                                      await backupProvider.setBackupFrequency(value);
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error: ${e.toString()}')),
                                      );
                                    }
                                  }
                                },
                              ),
                              const SizedBox(height: 8.0),
                              if (backupProvider.nextScheduledBackup != null) ...[  
                                Text(
                                  'Next backup: ${DateFormat('MMM d, yyyy h:mm a').format(backupProvider.nextScheduledBackup!)}',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12.0,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                    
                    // Import/Export Section
                    Card(
                      margin: const EdgeInsets.only(bottom: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      color: AppColors.darkCard,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.import_export),
                                const SizedBox(width: 8.0),
                                const Text(
                                  'Import/Export',
                                  style: TextStyle(
                                    fontSize: 18.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8.0),
                            const Text(
                              'Import data from Excel or export your data to Excel',
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 16.0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _importFromExcel,
                                    icon: const Icon(Icons.file_upload),
                                    label: const Text('Import'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.darkBackground,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8.0),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _exportToExcel,
                                    icon: const Icon(Icons.file_download),
                                    label: const Text('Export'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.darkBackground,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Backups List
                    if (isConnected && _backupsList.isNotEmpty) ...[
                      const Text(
                        'Available Backups',
                        style: TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      ...List.generate(
                        _backupsList.length,
                        (index) {
                          final backup = _backupsList[index];
                          final createdTime = backup['createdTime'] != null && backup['createdTime'].isNotEmpty
                              ? DateTime.parse(backup['createdTime'])
                              : null;
                          final formattedDate = createdTime != null
                              ? DateFormat.yMMMd().add_jm().format(createdTime)
                              : 'Unknown date';
                          final size = int.tryParse(backup['size'] ?? '0') ?? 0;
                          final sizeInKB = size / 1024;
                          final formattedSize = sizeInKB < 1024
                              ? '${sizeInKB.toStringAsFixed(1)} KB'
                              : '${(sizeInKB / 1024).toStringAsFixed(1)} MB';
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            color: AppColors.darkCard,
                            child: ListTile(
                              leading: const Icon(Icons.backup),
                              title: Text(backup['name'] ?? 'Backup'),
                              subtitle: Text('$formattedDate • $formattedSize'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Backup'),
                                      content: const Text(
                                        'Are you sure you want to delete this backup? This action cannot be undone.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  ) ?? false;
                                  
                                  if (confirm) {
                                    setState(() => _isLoading = true);
                                    
                                    try {
                                      final success = await backupProvider.googleDriveService
                                          .deleteBackup(backup['id']);
                                      
                                      if (!mounted) return;
                                      
                                      if (success) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Backup deleted')),
                                        );
                                        await _refreshBackupsList();
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Failed to delete backup')),
                                        );
                                      }
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error: ${e.toString()}')),
                                      );
                                    } finally {
                                      if (mounted) {
                                        setState(() => _isLoading = false);
                                      }
                                    }
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
