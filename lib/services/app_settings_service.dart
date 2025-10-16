import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global app settings (quote currency etc.) with persistence and notifications.
class AppSettingsService extends ChangeNotifier {
  static final AppSettingsService _instance = AppSettingsService._internal();
  factory AppSettingsService() => _instance;
  AppSettingsService._internal();

  static const String _kQuoteKey = 'quote_currency';
  static const String _kEnvKey = 'trading_env';

  String _quote = 'USDT';
  String _env = 'live'; // 'live' | 'testnet'
  bool _loaded = false;

  String get quoteCurrency => _quote;
  String get tradingEnvironment => _env;
  bool get isTestnet => _env.toLowerCase() == 'testnet';

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _quote = prefs.getString(_kQuoteKey) ?? 'USDT';
    _env = prefs.getString(_kEnvKey) ?? 'live';
    _loaded = true;
    notifyListeners();
  }

  Future<void> setQuoteCurrency(String quote) async {
    _quote = quote.toUpperCase();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kQuoteKey, _quote);
    notifyListeners();
  }

  Future<void> setTradingEnvironment(String env) async {
    final normalized = (env.toLowerCase() == 'testnet') ? 'testnet' : 'live';
    _env = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEnvKey, _env);
    notifyListeners();
  }

  static String currencyPrefix(String quote) {
    switch (quote.toUpperCase()) {
      case 'EUR':
        return '€';
      case 'USD':
      case 'USDT':
      case 'USDC':
      default:
        return r'$';
    }
  }
}


