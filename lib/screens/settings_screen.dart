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
      
      // Show success message with an action to open the file
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Export successful'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () {
              // Open the file using the shareFile method
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
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showChangePinDialog() {
    // Reset PIN values
    _currentPin = '';
    _newPin = '';
    _confirmPin = '';
    
    // Create local state variables for the dialog
    bool showCurrentPin = false;
    bool showNewPin = false;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Change PIN'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    obscureText: !showCurrentPin,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Current PIN',
                      suffixIcon: IconButton(
                        icon: Icon(showCurrentPin ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setDialogState(() => showCurrentPin = !showCurrentPin),
                      ),
                    ),
                    onChanged: (value) => _currentPin = value,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    obscureText: !showNewPin,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'New PIN',
                      suffixIcon: IconButton(
                        icon: Icon(showNewPin ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setDialogState(() => showNewPin = !showNewPin),
                      ),
                    ),
                    onChanged: (value) => _newPin = value,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    obscureText: !showNewPin,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New PIN',
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
                    // Validate inputs
                    if (_currentPin.isEmpty || _newPin.isEmpty || _confirmPin.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('Please fill all fields')),
                      );
                      return;
                    }
                    
                    if (_newPin != _confirmPin) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('New PIN and confirmation do not match')),
                      );
                      return;
                    }
                    
                    if (_newPin.length < 4) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('PIN must be at least 4 digits')),
                      );
                      return;
                    }
                    
                    // Change PIN
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final success = await authProvider.changePin(_currentPin, _newPin);
                    
                    if (!mounted) return;
                    
                    if (success) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('PIN changed successfully')),
                      );
                    } else {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text(authProvider.errorMessage ?? 'Failed to change PIN')),
                      );
                    }
                  },
                  child: const Text('Change'),
                ),
              ],
            );
          },
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
                        // Navigate directly to income categories page
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CategoriesScreen(isExpense: false),
                          ),
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
                    // Excel export button removed - now available in Backup & Restore screen
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
                  ],
                ),
                // Currency selection
                Consumer<SettingsProvider>(
                  builder: (context, settingsProvider, child) {
                    return _buildTile(
                      icon: Icons.currency_exchange,
                      title: 'Currency',
                      trailing: Text(
                        '${settingsProvider.currencyCode} (${settingsProvider.currencySymbol})',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      onTap: () {
                        // Show currency selection dialog
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Select Currency'),
                            content: SizedBox(
                              width: double.maxFinite,
                              height: 300,
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: SettingsProvider.availableCurrencies.length,
                                itemBuilder: (context, index) {
                                  final code = SettingsProvider.availableCurrencies.keys.elementAt(index);
                                  final symbol = SettingsProvider.availableCurrencies[code]!;
                                  return ListTile(
                                    title: Text('$code ($symbol)'),
                                    selected: code == settingsProvider.currencyCode,
                                    onTap: () {
                                      settingsProvider.setCurrency(code);
                                      Navigator.pop(context);
                                    },
                                  );
                                },
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                settingsProvider.themeMode == ThemeMode.system
                                    ? 'System'
                                    : settingsProvider.themeMode == ThemeMode.light
                                        ? 'Light'
                                        : 'Dark',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.secondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                settingsProvider.themeMode == ThemeMode.system
                                    ? Icons.settings
                                    : settingsProvider.themeMode == ThemeMode.light
                                        ? Icons.light_mode
                                        : Icons.dark_mode,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ],
                          ),
                          onTap: () {
                            // Show theme selection dialog
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Select Theme'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.settings),
                                      title: const Text('System'),
                                      selected: settingsProvider.themeMode == ThemeMode.system,
                                      onTap: () {
                                        settingsProvider.setThemeMode(ThemeMode.system);
                                        Navigator.pop(context);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.light_mode),
                                      title: const Text('Light'),
                                      selected: settingsProvider.themeMode == ThemeMode.light,
                                      onTap: () {
                                        settingsProvider.setThemeMode(ThemeMode.light);
                                        Navigator.pop(context);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.dark_mode),
                                      title: const Text('Dark'),
                                      selected: settingsProvider.themeMode == ThemeMode.dark,
                                      onTap: () {
                                        settingsProvider.setThemeMode(ThemeMode.dark);
                                        Navigator.pop(context);
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
                              ),
                            );
                          },
                        );
                      },
                    ),
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