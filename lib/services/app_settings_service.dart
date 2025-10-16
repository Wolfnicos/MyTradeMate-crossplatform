import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global app settings (quote currency etc.) with persistence and notifications.
class AppSettingsService extends ChangeNotifier {
  static final AppSettingsService _instance = AppSettingsService._internal();
  factory AppSettingsService() => _instance;
  AppSettingsService._internal();

  static const String _kQuoteKey = 'quote_currency';

  String _quote = 'USDT';
  bool _loaded = false;

  String get quoteCurrency => _quote;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _quote = prefs.getString(_kQuoteKey) ?? 'USDT';
    _loaded = true;
    notifyListeners();
  }

  Future<void> setQuoteCurrency(String quote) async {
    _quote = quote.toUpperCase();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kQuoteKey, _quote);
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


