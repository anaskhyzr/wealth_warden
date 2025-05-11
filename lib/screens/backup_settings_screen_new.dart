import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/providers.dart';
import '../utils/app_theme.dart';
import '../utils/size_formatter.dart';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _initBackupProvider();
  }
  
  Future<void> _initBackupProvider() async {
    final backupProvider = Provider.of<BackupProvider>(context, listen: false);
    
    setState(() => _isLoading = true);
    
    try {
      await backupProvider.init();
    } catch (e) {
      debugPrint('Error initializing backup provider: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  // Create a local backup
  Future<void> _createLocalBackup() async {
    final backupProvider = Provider.of<BackupProvider>(context, listen: false);
    
    setState(() => _isLoading = true);
    
    try {
      // Show a progress indicator in the UI
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Creating backup...'),
          duration: Duration(seconds: 1),
        ),
      );
      
      final success = await backupProvider.createBackup();
      
      if (!mounted) return;
      
      if (success) {
        final backupPath = backupProvider.lastBackupPath;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Backup created successfully'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Share',
              onPressed: () {
                if (backupPath != null) {
                  backupProvider.shareBackup(backupPath);
                }
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(backupProvider.errorMessage ?? 'Failed to create backup'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  // Restore from a backup file
  Future<void> _restoreFromBackup() async {
    final backupProvider = Provider.of<BackupProvider>(context, listen: false);
    
    // TODO: Implement file picker to select backup file
    // For now, just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('File picker is temporarily disabled. Please use the Export/Import Excel options instead.'),
        backgroundColor: Colors.orange,
      ),
    );
  }
  
  // Export to Excel
  Future<void> _exportToExcel() async {
    final backupProvider = Provider.of<BackupProvider>(context, listen: false);
    
    setState(() => _isLoading = true);
    
    try {
      final filePath = await backupProvider.exportToExcel();
      
      if (!mounted) return;
      
      if (filePath == null || filePath.isEmpty) {
        final errorMessage = backupProvider.errorMessage;
        throw Exception(errorMessage ?? 'Export failed');
      }
      
      // Show success message with an action to open the file
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Export successful'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Open',
            onPressed: () {
              backupProvider.shareFile(filePath);
            },
          ),
        ),
      );
      
      // Automatically open the file after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          backupProvider.shareFile(filePath);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  // Import from Excel
  Future<void> _importFromExcel() async {
    final backupProvider = Provider.of<BackupProvider>(context, listen: false);
    
    // TODO: Implement file picker to select Excel file
    // For now, just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('File picker is temporarily disabled.'),
        backgroundColor: Colors.orange,
      ),
    );
  }
  
  // Upload to Google Drive
  Future<void> _uploadToGoogleDrive() async {
    final backupProvider = Provider.of<BackupProvider>(context, listen: false);
    
    setState(() => _isLoading = true);
    
    try {
      // First ensure we have a recent backup
      final hasBackup = backupProvider.lastBackupPath != null;
      
      if (!hasBackup) {
        // Create a backup first
        final backupSuccess = await backupProvider.createBackup();
        if (!backupSuccess) {
          throw Exception('Failed to create backup before uploading');
        }
      }
      
      // Now upload to Google Drive
      final success = await backupProvider.backupToGoogleDrive();
      
      if (!mounted) return;
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup uploaded to Google Drive successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(backupProvider.errorMessage ?? 'Failed to upload to Google Drive'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  // Download from Google Drive
  Future<void> _downloadFromGoogleDrive() async {
    final backupProvider = Provider.of<BackupProvider>(context, listen: false);
    
    setState(() => _isLoading = true);
    
    try {
      // Show confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restore from Google Drive'),
          content: const Text(
            'This will replace all your current data with the data from the backup. '
            'This action cannot be undone. Are you sure you want to continue?',
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
      
      if (!confirm) {
        setState(() => _isLoading = false);
        return;
      }
      
      // Show a progress indicator in the UI
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Downloading from Google Drive...'),
          duration: Duration(seconds: 2),
        ),
      );
      
      final success = await backupProvider.restoreFromGoogleDrive();
      
      if (!mounted) return;
      
      if (success) {
        // Show success message with restart button
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Restore Successful'),
            content: const Text(
              'Your data has been restored successfully. '
              'The app needs to restart to apply all changes.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  // Restart app logic - for now just pop to login screen
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Restart Now'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(backupProvider.errorMessage ?? 'Failed to restore from Google Drive'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
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
    final isGoogleDriveConnected = backupProvider.isGoogleDriveConnected;
    final lastBackupDate = backupProvider.lastBackupDate;
    final lastGDriveBackupDate = backupProvider.lastGoogleDriveBackupDate != null 
        ? DateTime.parse(backupProvider.lastGoogleDriveBackupDate!) 
        : null;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
        backgroundColor: AppColors.darkAppBar,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Local Backup Card
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
                              const Icon(
                                Icons.save,
                                color: AppColors.primaryGreen,
                                size: 24.0,
                              ),
                              const SizedBox(width: 8.0),
                              Text(
                                'Local Backup',
                                style: TextStyle(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkTextPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            'Create and manage local backups of your data',
                            style: TextStyle(
                              color: AppColors.darkTextSecondary,
                            ),
                          ),
                          if (lastBackupDate != null) ...[
                            const SizedBox(height: 8.0),
                            Text(
                              'Last backup: ${DateFormat.yMMMd().add_jm().format(lastBackupDate)}',
                              style: TextStyle(
                                color: AppColors.darkTextSecondary,
                                fontSize: 12.0,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16.0),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _createLocalBackup,
                                  icon: const Icon(Icons.save),
                                  label: const Text('Create Backup'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryGreen,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _restoreFromBackup,
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
                      ),
                    ),
                  ),
                  
                  // Google Drive Card
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
                              const Icon(
                                Icons.cloud,
                                color: AppColors.primaryGreen,
                                size: 24.0,
                              ),
                              const SizedBox(width: 8.0),
                              Text(
                                'Google Drive',
                                style: TextStyle(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.bold,
                                  color: isGoogleDriveConnected
                                      ? AppColors.darkTextPrimary
                                      : Colors.grey,
                                ),
                              ),
                              const Spacer(),
                              Switch(
                                value: isGoogleDriveConnected,
                                onChanged: (value) async {
                                  setState(() => _isLoading = true);
                                  try {
                                    if (value) {
                                      await backupProvider.connectToGoogleDrive();
                                    } else {
                                      await backupProvider.disconnectFromGoogleDrive();
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() => _isLoading = false);
                                    }
                                  }
                                },
                                activeColor: AppColors.primaryGreen,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            isGoogleDriveConnected
                                ? 'Connected to Google Drive'
                                : 'Connect to Google Drive to backup your data',
                            style: TextStyle(
                              color: AppColors.darkTextSecondary,
                            ),
                          ),
                          if (isGoogleDriveConnected && lastGDriveBackupDate != null) ...[
                            const SizedBox(height: 8.0),
                            Text(
                              'Last Google Drive backup: ${DateFormat.yMMMd().add_jm().format(lastGDriveBackupDate)}',
                              style: TextStyle(
                                color: AppColors.darkTextSecondary,
                                fontSize: 12.0,
                              ),
                            ),
                          ],
                          if (isGoogleDriveConnected) ...[
                            const SizedBox(height: 16.0),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _uploadToGoogleDrive,
                                    icon: const Icon(Icons.cloud_upload),
                                    label: const Text('Upload'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryGreen,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8.0),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _downloadFromGoogleDrive,
                                    icon: const Icon(Icons.cloud_download),
                                    label: const Text('Download'),
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
                  
                  // Excel Import/Export Card
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
                              const Icon(
                                Icons.table_chart,
                                color: AppColors.primaryGreen,
                                size: 24.0,
                              ),
                              const SizedBox(width: 8.0),
                              Text(
                                'Excel Import/Export',
                                style: TextStyle(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkTextPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            'Import or export your data as Excel spreadsheets',
                            style: TextStyle(
                              color: AppColors.darkTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 16.0),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _exportToExcel,
                                  icon: const Icon(Icons.download),
                                  label: const Text('Export'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryGreen,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _importFromExcel,
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text('Import'),
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
                  
                  // Help Text
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Note: Regular backups are recommended to prevent data loss. '
                      'Excel export is useful for viewing and editing your data in spreadsheet applications.',
                      style: TextStyle(
                        color: AppColors.darkTextSecondary,
                        fontSize: 12.0,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
