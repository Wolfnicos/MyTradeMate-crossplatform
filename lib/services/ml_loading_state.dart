import 'package:flutter/foundation.dart';

/// Global state tracker for ML model loading
/// Allows UI to show loading indicators while models load in background
class MLLoadingState extends ChangeNotifier {
  static final MLLoadingState _instance = MLLoadingState._internal();
  factory MLLoadingState() => _instance;
  MLLoadingState._internal();

  bool _isLoading = true;
  String _loadingStatus = 'Initializing AI models...';
  double _progress = 0.0; // 0.0 to 1.0

  bool get isLoading => _isLoading;
  String get loadingStatus => _loadingStatus;
  double get progress => _progress;

  void updateStatus(String status, double progress) {
    _loadingStatus = status;
    _progress = progress;
    notifyListeners();
  }

  void setLoaded() {
    _isLoading = false;
    _loadingStatus = 'AI models ready';
    _progress = 1.0;
    notifyListeners();
  }

  void reset() {
    _isLoading = true;
    _loadingStatus = 'Initializing AI models...';
    _progress = 0.0;
    notifyListeners();
  }
}
