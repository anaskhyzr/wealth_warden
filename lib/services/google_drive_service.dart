import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoogleDriveService {
  // Singleton instance
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  
  // Constants for folder and file names
  static const String _appFolderName = 'WealthWarden';
  static const String _backupFileName = 'wealth_warden_backup.json';
  
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/drive.file',
    ],
  );
  
  drive.DriveApi? _driveApi;
  bool _isSignedIn = false;
  String? _lastBackupDate;
  
  factory GoogleDriveService() => _instance;
  
  GoogleDriveService._internal();
  
  bool get isSignedIn => _isSignedIn;
  String? get lastBackupDate => _lastBackupDate;
  
  // Initialize the service
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastBackupDate = prefs.getString('last_backup_date');
      
      // Check if user is already signed in
      final isSignedIn = await _googleSignIn.isSignedIn();
      if (isSignedIn) {
        await _signInSilently();
      }
    } catch (e) {
      debugPrint('Error initializing Google Drive service: $e');
    }
  }
  
  // Sign in silently (without UI)
  Future<bool> _signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        await _initializeDriveApi(account);
        _isSignedIn = true;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error signing in silently: $e');
      return false;
    }
  }
  
  // Sign in with UI
  Future<bool> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        await _initializeDriveApi(account);
        _isSignedIn = true;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error signing in: $e');
      return false;
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _driveApi = null;
      _isSignedIn = false;
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }
  
  // Initialize the Drive API
  Future<void> _initializeDriveApi(GoogleSignInAccount account) async {
    final authHeaders = await account.authHeaders;
    final client = GoogleAuthClient(authHeaders);
    _driveApi = drive.DriveApi(client);
  }
  
  // Find or create app folder
  Future<String?> _findOrCreateAppFolder() async {
    if (_driveApi == null) {
      throw Exception('Drive API not initialized');
    }
    
    try {
      // Search for existing folder
      final folderList = await _driveApi!.files.list(
        q: "name='$_appFolderName' and mimeType='application/vnd.google-apps.folder' and trashed=false",
        $fields: 'files(id, name)',
      );
      
      if (folderList.files != null && folderList.files!.isNotEmpty) {
        return folderList.files!.first.id;
      }
      
      // Create folder if it doesn't exist
      final folder = drive.File()
        ..name = _appFolderName
        ..mimeType = 'application/vnd.google-apps.folder';
      
      final createdFolder = await _driveApi!.files.create(folder);
      return createdFolder.id;
    } catch (e) {
      debugPrint('Error finding or creating app folder: $e');
      return null;
    }
  }
  
  // Find backup file in app folder
  Future<String?> _findBackupFile(String folderId) async {
    if (_driveApi == null) {
      throw Exception('Drive API not initialized');
    }
    
    try {
      final fileList = await _driveApi!.files.list(
        q: "name='$_backupFileName' and '$folderId' in parents and trashed=false",
        $fields: 'files(id, name, modifiedTime)',
      );
      
      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final file = fileList.files!.first;
        if (file.modifiedTime != null) {
          _lastBackupDate = file.modifiedTime!.toIso8601String();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('last_backup_date', _lastBackupDate!);
        }
        return file.id;
      }
      
      return null;
    } catch (e) {
      debugPrint('Error finding backup file: $e');
      return null;
    }
  }
  
  // Upload backup to Google Drive
  Future<bool> uploadBackup(Map<String, dynamic> backupData) async {
    if (!_isSignedIn) {
      final success = await signIn();
      if (!success) return false;
    }
    
    try {
      final folderId = await _findOrCreateAppFolder();
      if (folderId == null) return false;
      
      // Convert backup data to JSON
      final jsonData = jsonEncode(backupData);
      
      // Create temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$_backupFileName');
      await tempFile.writeAsString(jsonData);
      
      // Find existing backup file
      final existingFileId = await _findBackupFile(folderId);
      
      final contentStream = tempFile.openRead();
      final mediaUpload = drive.Media(contentStream, tempFile.lengthSync());
      
      if (existingFileId != null) {
        // Update existing file
        final driveFile = drive.File()
          ..name = _backupFileName;
        
        await _driveApi!.files.update(
          driveFile,
          existingFileId,
          uploadMedia: mediaUpload,
        );
      } else {
        // Create new file
        final driveFile = drive.File()
          ..name = _backupFileName
          ..parents = [folderId];
        
        await _driveApi!.files.create(
          driveFile,
          uploadMedia: mediaUpload,
        );
      }
      
      // Update last backup date
      _lastBackupDate = DateTime.now().toIso8601String();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_backup_date', _lastBackupDate!);
      
      // Clean up
      await tempFile.delete();
      
      return true;
    } catch (e) {
      debugPrint('Error uploading backup: $e');
      return false;
    }
  }
  
  // Download backup from Google Drive
  Future<Map<String, dynamic>?> downloadBackup() async {
    if (!_isSignedIn) {
      final success = await signIn();
      if (!success) return null;
    }
    
    try {
      final folderId = await _findOrCreateAppFolder();
      if (folderId == null) return null;
      
      final fileId = await _findBackupFile(folderId);
      if (fileId == null) return null;
      
      // Download file
      final media = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      
      // Read file content
      final bytes = await media.stream.toList();
      final content = utf8.decode(bytes.expand((x) => x).toList());
      
      // Parse JSON
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error downloading backup: $e');
      return null;
    }
  }
  
  // List all backups in the app folder
  Future<List<Map<String, dynamic>>> listBackups() async {
    if (!_isSignedIn) {
      final success = await signIn();
      if (!success) return [];
    }
    
    try {
      final folderId = await _findOrCreateAppFolder();
      if (folderId == null) return [];
      
      final fileList = await _driveApi!.files.list(
        q: "'$folderId' in parents and trashed=false",
        $fields: 'files(id, name, modifiedTime, size)',
      );
      
      if (fileList.files == null || fileList.files!.isEmpty) {
        return [];
      }
      
      return fileList.files!.map((file) {
        return {
          'id': file.id ?? '',
          'name': file.name ?? '',
          'modifiedTime': file.modifiedTime?.toIso8601String() ?? '',
          'size': file.size ?? '0',
        };
      }).toList();
    } catch (e) {
      debugPrint('Error listing backups: $e');
      return [];
    }
  }
  
  // Delete a backup file
  Future<bool> deleteBackup(String fileId) async {
    if (!_isSignedIn) {
      final success = await signIn();
      if (!success) return false;
    }
    
    try {
      await _driveApi!.files.delete(fileId);
      return true;
    } catch (e) {
      debugPrint('Error deleting backup: $e');
      return false;
    }
  }
}

// HTTP client for Google API
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();
  
  GoogleAuthClient(this._headers);
  
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}
