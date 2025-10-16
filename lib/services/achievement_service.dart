import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AchievementService extends ChangeNotifier {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  static const String _kKey = 'achievements_unlocked';

  final Set<String> _unlocked = <String>{};

  Set<String> get unlocked => Set<String>.from(_unlocked);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kKey) ?? <String>[];
      _unlocked
        ..clear()
        ..addAll(list);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> unlock(String id) async {
    if (_unlocked.contains(id)) return;
    _unlocked.add(id);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kKey, _unlocked.toList(growable: false));
    } catch (_) {}
    notifyListeners();
  }

  bool isUnlocked(String id) => _unlocked.contains(id);
}


