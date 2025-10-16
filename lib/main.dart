import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ml/tflite_predictor.dart';
import 'ml/ml_service.dart';
import 'providers/theme_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/market_screen.dart';
import 'screens/ai_strategies_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/portfolio_screen.dart';
import 'screens/settings_screen.dart';
import 'services/app_settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  await AppSettingsService().load();
  await globalPredictor.init();
  await globalMlService.loadModel();

  // Initialize theme provider
  final themeProvider = ThemeProvider();
  await themeProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: AppSettingsService()),
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
      // Tema pentru modul Luminos (Light Mode) - Premium 2025
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA), // Soft off-white
        cardColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0066FF), // Vibrant Blue
          primaryContainer: Color(0xFFE3F2FD),
          secondary: Color(0xFF00C853), // Vivid Green
          secondaryContainer: Color(0xFFE8F5E9),
          tertiary: Color(0xFF7C4DFF), // Purple accent
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          surface: Colors.white,
          surfaceContainerHighest: Color(0xFFF5F5F5),
          onSurface: Color(0xFF1A1A1A),
          error: Color(0xFFFF3B30), // iOS Red
          onError: Colors.white,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A), letterSpacing: -0.5),
          displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A), letterSpacing: -0.5),
          headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
          headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF4A4A4A)),
          bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF1A1A1A)),
          bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF4A4A4A)),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shadowColor: Colors.black.withOpacity(0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          color: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: Color(0xFFF8F9FA),
          foregroundColor: Color(0xFF1A1A1A),
          titleTextStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: const Color(0xFF0066FF),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            side: const BorderSide(color: Color(0xFF0066FF), width: 2),
            foregroundColor: const Color(0xFF0066FF),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF0066FF), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        useMaterial3: true,
      ),
      // Tema pentru modul Întunecat (Dark Mode) - Premium 2025
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A), // Rich Black
        cardColor: const Color(0xFF1C1C1E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0A84FF), // Electric Blue
          primaryContainer: Color(0xFF1E3A5F),
          secondary: Color(0xFF30D158), // Neon Green
          secondaryContainer: Color(0xFF1A3A2A),
          tertiary: Color(0xFFBF5AF2), // Purple
          onPrimary: Colors.black,
          onSecondary: Colors.black,
          surface: Color(0xFF1C1C1E),
          surfaceContainerHighest: Color(0xFF2C2C2E),
          onSurface: Color(0xFFF5F5F7),
          error: Color(0xFFFF453A),
          onError: Colors.white,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFF5F5F7), letterSpacing: -0.5),
          displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFF5F5F7), letterSpacing: -0.5),
          headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFF5F5F7)),
          headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFFF5F5F7)),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFFF5F5F7)),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFFAAAAAA)),
          bodyLarge: TextStyle(fontSize: 16, color: Color(0xFFE5E5E7)),
          bodyMedium: TextStyle(fontSize: 14, color: Color(0xFFAAAAAA)),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shadowColor: Colors.white.withOpacity(0.03),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          color: const Color(0xFF1C1C1E),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: Color(0xFF0A0A0A),
          foregroundColor: Color(0xFFF5F5F7),
          titleTextStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFF5F5F7)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: const Color(0xFF0A84FF),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            side: const BorderSide(color: Color(0xFF0A84FF), width: 2),
            foregroundColor: const Color(0xFF0A84FF),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2C2C2E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF0A84FF), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        useMaterial3: true,
      ),
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
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    DashboardScreen(),
    MarketScreen(),
    AiStrategiesScreen(),
    OrdersScreen(),
    PortfolioScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
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
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Market'),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: 'AI'),
          BottomNavigationBarItem(icon: Icon(Icons.swap_horiz), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Portfolio'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        backgroundColor: Theme.of(context).cardColor,
      ),
    );
  }
}
