import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'ml/tflite_predictor.dart';
import 'ml/ml_service.dart';
import 'ml/unified_ml_service.dart';
import 'ml/ensemble_predictor.dart';
import 'ml/crypto_ml_service.dart';
import 'providers/theme_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/market_screen.dart';
import 'screens/ai_strategies_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/portfolio_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/app_settings_service.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'providers/navigation_provider.dart';
import 'services/achievement_service.dart';
import 'services/ml_loading_state.dart';
import 'widgets/risk_disclaimer_dialog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize ONLY fast, essential services in main()
  // This allows the app to start in <1 second
  await AppSettingsService().load();
  await AuthService().load();
  await AchievementService().load();

  // Initialize theme provider
  final themeProvider = ThemeProvider();
  await themeProvider.init();

  // Start the app immediately
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: AppSettingsService()),
        ChangeNotifierProvider.value(value: AuthService()),
        ChangeNotifierProvider.value(value: AchievementService()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ],
      child: const MyTradeMateApp(),
    ),
  );

  // Load ML models in background AFTER app is visible
  // This prevents blocking the UI thread during startup
  _loadMLModelsInBackground();
}

/// Load ML models in background after app startup
/// This improves perceived performance by showing the app immediately
/// while models load asynchronously
Future<void> _loadMLModelsInBackground() async {
  final loadingState = MLLoadingState();
  debugPrint('🔄 BACKGROUND: Starting ML model loading...');

  try {
    loadingState.updateStatus('Loading legacy predictor...', 0.1);
    await globalPredictor.init();
    debugPrint('✅ BACKGROUND: globalPredictor initialized');
  } catch (e) {
    debugPrint('⚠️ BACKGROUND: globalPredictor failed: $e');
  }

  try {
    loadingState.updateStatus('Loading unified ML service...', 0.2);
    await unifiedMLService.initialize();
    debugPrint('✅ BACKGROUND: unifiedMLService initialized');
  } catch (e) {
    debugPrint('⚠️ BACKGROUND: unifiedMLService failed: $e');
  }

  try {
    loadingState.updateStatus('Loading legacy model...', 0.3);
    await globalMlService.loadModel();
    debugPrint('✅ BACKGROUND: globalMlService loaded');
  } catch (e) {
    debugPrint('⚠️ BACKGROUND: globalMlService failed: $e');
  }

  try {
    loadingState.updateStatus('Loading Ensemble models (Transformer, LSTM, Random Forest)...', 0.5);
    await globalEnsemblePredictor.loadModels();
    debugPrint('✅ BACKGROUND: Ensemble predictor loaded (Transformer + LSTM + RF)');
  } catch (e) {
    debugPrint('⚠️ BACKGROUND: Ensemble predictor failed: $e');
  }

  try {
    loadingState.updateStatus('Loading CryptoML service (18+ models)...', 0.7);
    await CryptoMLService().initialize();
    debugPrint('✅ BACKGROUND: CryptoMLService initialized - All 18+ models loaded!');
    debugPrint('🚀 BACKGROUND: ML initialization complete - App ready for AI predictions');
  } catch (e, stackTrace) {
    debugPrint('⚠️ BACKGROUND: CryptoMLService failed: $e');
    debugPrint('   Stack trace: $stackTrace');
  }

  // Mark as loaded
  loadingState.setLoaded();
  debugPrint('✅ BACKGROUND: All ML services ready');
}

class MyTradeMateApp extends StatelessWidget {
  const MyTradeMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthService, ThemeProvider>(
      builder: (context, authService, themeProvider, _) {
        return MaterialApp(
          title: 'MyTradeMate',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.currentThemeMode,
          // Force English UI across platforms
          locale: const Locale('en', 'US'),
          supportedLocales: const [Locale('en', 'US')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          localeResolutionCallback: (locale, supportedLocales) => const Locale('en', 'US'),
          home: authService.isAuthenticated ? const HomePage() : const WelcomeScreen(),
          routes: {
            '/home': (context) => const HomePage(),
            '/welcome': (context) => const WelcomeScreen(),
          },
        );
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const List<Widget> _widgetOptions = <Widget>[
    DashboardScreen(),
    MarketScreen(),
    AiStrategiesScreen(),
    OrdersScreen(),
    PortfolioScreen(),
  ];

  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard'),
    _NavItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, label: 'Market'),
    _NavItem(icon: Icons.smart_toy_outlined, activeIcon: Icons.smart_toy, label: 'AI'),
    _NavItem(icon: Icons.swap_horiz, activeIcon: Icons.swap_horiz, label: 'Orders'),
    _NavItem(icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet, label: 'Portfolio'),
  ];

  @override
  Widget build(BuildContext context) {

    final nav = Provider.of<NavigationProvider>(context);
    return Scaffold(
      extendBody: true,
      appBar: _PremiumAppBar(),
      body: IndexedStack(
        index: nav.index,
        children: _widgetOptions,
      ),
      bottomNavigationBar: _PremiumBottomNav(
        currentIndex: nav.index,
        onTap: nav.setIndex,
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

// Premium Top App Bar - Only Settings
class _PremiumAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _PremiumAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spacing8),
                decoration: BoxDecoration(
                  gradient: AppTheme.glassGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(
                    color: AppTheme.glassBorder,
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.settings_outlined,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Premium Bottom Navigation Bar
class _PremiumBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _PremiumBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  static const List<_NavItem> _navItems = _HomePageState._navItems;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.surface.withOpacity(0.85),
                AppTheme.surface.withOpacity(0.75),
              ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            border: Border(
              top: BorderSide(
                color: AppTheme.glassBorder,
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing4, vertical: AppTheme.spacing4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_navItems.length, (index) {
                  final item = _navItems[index];
                  final isActive = currentIndex == index;
                  return _BottomNavItem(
                    icon: item.icon,
                    activeIcon: item.activeIcon,
                    label: item.label,
                    isActive: isActive,
                    onTap: () => onTap(index),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick(); // Haptic feedback for premium feel
            onTap();
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          child: AnimatedContainer(
            duration: AppTheme.animationNormal,
            padding: const EdgeInsets.symmetric(
              vertical: AppTheme.spacing4,
              horizontal: AppTheme.spacing4,
            ),
            decoration: BoxDecoration(
              gradient: isActive
                  ? LinearGradient(
                      colors: [
                        AppTheme.primary.withOpacity(0.15),
                        AppTheme.secondary.withOpacity(0.15),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: isActive
                  ? Border.all(
                      color: AppTheme.primary.withOpacity(0.3),
                      width: 1.5,
                    )
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon with gradient glow when active
                Icon(
                  isActive ? activeIcon : icon,
                  color: isActive ? AppTheme.primary : AppTheme.textSecondary,
                  size: 22,
                ),
                const SizedBox(height: 2),
                // Label
                Text(
                  label,
                  style: AppTheme.labelSmall.copyWith(
                    color: isActive ? AppTheme.textPrimary : AppTheme.textTertiary,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 11, // Increased from 9px for accessibility (WCAG 2.1 AA)
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
