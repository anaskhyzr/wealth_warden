import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'login_screen.dart';
import 'backup_settings_screen.dart';
import 'categories_screen.dart';
import '../providers/providers.dart';
import '../utils/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isExporting = false;
  String _currentPin = '';
  String _newPin = '';
  String _confirmPin = '';
  bool _showCurrentPin = false;
  bool _showNewPin = false;

  Future<void> _handleExitApp() async {
    try {
      // First lock the app by signing out
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.signOut();
      
      // Navigate to login screen and remove all previous routes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
      
      // Exit the app
      // Note: This will only work on Android and iOS
      // For web, this will have no effect
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App locked. Exiting...')),
      );
      
      // Wait for the snackbar to be visible
      await Future.delayed(const Duration(seconds: 1));
      
      // Exit the app on Android/iOS
      SystemNavigator.pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to exit: ${e.toString()}')),
      );
    }
  }

  Future<void> _exportToExcel() async {
    if (_isExporting) return;

    try {
      setState(() => _isExporting = true);
      
      final backupProvider = Provider.of<BackupProvider>(context, listen: false);
      final filePath = await backupProvider.exportToExcel();
      
      if (!mounted) return;
      
      if (filePath == null || filePath.isEmpty) {
        final errorMessage = backupProvider.errorMessage;
        throw Exception(errorMessage ?? 'Export failed');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export successful: $filePath')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showChangePinDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                obscureText: !_showCurrentPin,
                decoration: InputDecoration(
                  labelText: 'Current PIN',
                  suffixIcon: IconButton(
                    icon: Icon(_showCurrentPin ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _showCurrentPin = !_showCurrentPin),
                  ),
                ),
                onChanged: (value) => _currentPin = value,
              ),
              TextField(
                obscureText: !_showNewPin,
                decoration: InputDecoration(
                  labelText: 'New PIN',
                  suffixIcon: IconButton(
                    icon: Icon(_showNewPin ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _showNewPin = !_showNewPin),
                  ),
                ),
                onChanged: (value) => _newPin = value,
              ),
              TextField(
                obscureText: !_showNewPin,
                decoration: InputDecoration(
                  labelText: 'Confirm PIN',
                ),
                onChanged: (value) => _confirmPin = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (_newPin != _confirmPin) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('New PIN and Confirm PIN do not match'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                try {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  final success = await authProvider.changePin(_currentPin, _newPin);
                  
                  if (!context.mounted) return;
                  
                  if (success) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PIN changed successfully')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to change PIN. Current PIN may be incorrect.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error changing PIN: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Change'),
            ),
          ],
        );
      },
    );
  }

  // Biometric authentication removed

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection(
                  'Data Management',
                  [
                    _buildTile(
                      icon: Icons.category,
                      title: 'Categories',
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => const _CategoryTypeDialog(),
                        );
                      },
                    ),
                    _buildTile(
                      icon: Icons.backup,
                      title: 'Backup & Restore',
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const BackupSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    _buildTile(
                      icon: Icons.file_download,
                      title: 'Export to Excel',
                      trailing: _isExporting 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                      onTap: _exportToExcel,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSection(
                  'Security',
                  [
                    _buildTile(
                      icon: Icons.lock,
                      title: 'Change PIN',
                      trailing: const Text(
                        'Change',
                        style: TextStyle(color: Colors.green),
                      ),
                      onTap: _showChangePinDialog,
                    ),
                    // Biometric authentication removed
                  ],
                ),
                const SizedBox(height: 24),
                _buildSection(
                  'Appearance',
                  [
                    Consumer<SettingsProvider>(
                      builder: (context, settingsProvider, child) {
                        return _buildTile(
                          icon: Icons.palette,
                          title: 'Theme',
                          trailing: DropdownButton<ThemeMode>(
                            value: settingsProvider.themeMode,
                            underline: const SizedBox(),
                            onChanged: (ThemeMode? newMode) {
                              if (newMode != null) {
                                settingsProvider.setThemeMode(newMode);
                              }
                            },
                            items: const [
                              DropdownMenuItem(
                                value: ThemeMode.system,
                                child: Text('System'),
                              ),
                              DropdownMenuItem(
                                value: ThemeMode.light,
                                child: Text('Light'),
                              ),
                              DropdownMenuItem(
                                value: ThemeMode.dark,
                                child: Text('Dark'),
                              ),
                            ],
                          ),
                          onTap: () {},
                        );
                      },
                    ),
                    // Primary color switch removed
                  ],
                ),
                const SizedBox(height: 24),
                _buildSection(
                  'Application',
                  [
                    _buildTile(
                      icon: Icons.exit_to_app,
                      title: 'Exit App',
                      trailing: const Icon(Icons.logout, color: Colors.red),
                      onTap: _handleExitApp,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: trailing,
      onTap: onTap,
    );
  }
  
  // Color selector removed
}

// Dialog to select category type (income or expense)
class _CategoryTypeDialog extends StatelessWidget {
  const _CategoryTypeDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Category Type'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.arrow_upward, color: Colors.green),
            title: const Text('Income Categories'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CategoriesScreen(isExpense: false),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.arrow_downward, color: Colors.red),
            title: const Text('Expense Categories'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CategoriesScreen(isExpense: true),
                ),
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}