import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global app settings (quote currency etc.) with persistence and notifications.
class AppSettingsService extends ChangeNotifier {
  static final AppSettingsService _instance = AppSettingsService._internal();
  factory AppSettingsService() => _instance;
  AppSettingsService._internal();

  static const String _kQuoteKey = 'quote_currency';
  static const String _kPermissionKey = 'api_permission_level';

  String _quote = 'USDT';
  String _permissionLevel = 'read'; // 'read' | 'trading'
  bool _loaded = false;

  String get quoteCurrency => _quote;
  String get permissionLevel => _permissionLevel;
  bool get isTradingEnabled => _permissionLevel.toLowerCase() == 'trading';

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _quote = prefs.getString(_kQuoteKey) ?? 'USDT';
    _permissionLevel = prefs.getString(_kPermissionKey) ?? 'read';
    _loaded = true;
    notifyListeners();
  }

  Future<void> setQuoteCurrency(String quote) async {
    _quote = quote.toUpperCase();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kQuoteKey, _quote);
    notifyListeners();
  }

  Future<void> setPermissionLevel(String level) async {
    final normalized = (level.toLowerCase() == 'trading') ? 'trading' : 'read';
    _permissionLevel = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPermissionKey, _permissionLevel);
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


