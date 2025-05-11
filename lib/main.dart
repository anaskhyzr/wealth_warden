import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/pin_setup_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/enhanced_stats_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/transaction_screen.dart';
import 'providers/providers.dart';
import 'db/database_helper.dart';
import 'utils/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final initialRoute = await _determineInitialRoute();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => RecurringTransactionProvider()),
        ChangeNotifierProvider(create: (_) => BackupProvider()),
      ],
      child: WealthWarden(initialRoute: initialRoute),
    ),
  );
}

Future<String> _determineInitialRoute() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
    final hasPin = prefs.getString('pin') != null;
    
    if (!onboardingComplete) {
      return '/onboarding';
    } else if (!hasPin) {
      return '/setup';
    } else {
      return '/login';
    }
  } catch (e) {
    debugPrint('Error determining initial route: $e');
    return '/onboarding'; // Fallback to onboarding
  }
}

class WealthWarden extends StatefulWidget {
  final String initialRoute;

  const WealthWarden({
    super.key,
    required this.initialRoute,
  });

  @override
  State<WealthWarden> createState() => _WealthWardenState();
}

class _WealthWardenState extends State<WealthWarden> {
  @override
  void initState() {
    super.initState();
    
    // Initialize providers
    Future.delayed(Duration.zero, () {
      // Initialize BackupProvider
      Provider.of<BackupProvider>(context, listen: false).init();
    });
    
    _initializeProviders();
  }

  Future<void> _initializeProviders() async {
    try {
      // Initialize settings first as other providers may depend on it
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      await settingsProvider.loadSettings();
      
      // Initialize auth provider
      await Provider.of<AuthProvider>(context, listen: false).initAuth();
      
      // Initialize categories only at startup - this is needed for the UI
      await Provider.of<CategoryProvider>(context, listen: false).loadCategories();
      
      // Defer loading of other providers until after navigation to main screen
      // This will make the login to main screen transition much faster
      // The MainScreen will handle loading transactions and other data
    } catch (e) {
      debugPrint('Error initializing providers: $e');
    }
  }


  
  @override
  Widget build(BuildContext context) {
    // Get theme settings from the provider - use listen: true to rebuild when theme changes
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        return MaterialApp(
          title: 'WealthWarden',
          debugShowCheckedModeBanner: false,
          themeMode: settingsProvider.themeMode,
          darkTheme: AppTheme.darkTheme,
          theme: AppTheme.lightTheme,
          initialRoute: widget.initialRoute,
          routes: _buildRoutes(),
        );
      },
    );
  }

  Map<String, WidgetBuilder> _buildRoutes() {
    return {
      '/onboarding': (context) => const OnboardingScreen(),
      '/setup': (context) => const PinSetupScreen(),
      '/login': (context) => const LoginScreen(),
      '/home': (context) => const MainScreen(),
    };
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const DashboardScreen(),
    const StatsScreen(),
    const SettingsScreen(),
  ];

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.darkBackground,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: AppColors.darkBackground,
          selectedItemColor: AppColors.primaryGreen,
          unselectedItemColor: AppColors.darkTextSecondary,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Stats',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
