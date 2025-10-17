import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ml/tflite_predictor.dart';
import 'ml/ml_service.dart';
import 'ml/ensemble_predictor.dart';
import 'providers/theme_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/market_screen.dart';
import 'screens/ai_strategies_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/portfolio_screen.dart';
import 'screens/settings_screen.dart';
import 'services/app_settings_service.dart';
import 'design_system/app_theme.dart';
import 'providers/navigation_provider.dart';
import 'services/achievement_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  await AppSettingsService().load();
  await globalPredictor.init();
  await globalMlService.loadModel();

  // Initialize NEW Ensemble Predictor (Transformer + LSTM + RF)
  try {
    await globalEnsemblePredictor.loadModels();
    debugPrint('🚀 NEW AI models activated!');
  } catch (e) {
    debugPrint('⚠️ Ensemble predictor failed to load: $e');
    debugPrint('   Falling back to legacy TCN model');
  }

  await AchievementService().load();

  // Initialize theme provider
  final themeProvider = ThemeProvider();
  await themeProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: AppSettingsService()),
        ChangeNotifierProvider.value(value: AchievementService()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ],
      child: const MyTradeMateApp(),
    ),
  );
}

class MyTradeMateApp extends StatelessWidget {
  const MyTradeMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'MyTradeMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(context),
      darkTheme: AppTheme.dark(context),
      themeMode: themeProvider.currentThemeMode,
      home: const HomePage(),
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

  @override
  Widget build(BuildContext context) {
    final nav = Provider.of<NavigationProvider>(context);
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Center(
        child: _widgetOptions.elementAt(nav.index),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Market'),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: 'AI'),
          BottomNavigationBarItem(icon: Icon(Icons.swap_horiz), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Portfolio'),
        ],
        currentIndex: nav.index,
        onTap: nav.setIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).bottomNavigationBarTheme.unselectedItemColor,
        backgroundColor: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
      ),
      bottomSheet: Container(
        height: 0.01,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2E2E33)
                  : const Color(0xFF1F2937),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}
