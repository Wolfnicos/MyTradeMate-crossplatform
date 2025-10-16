import 'package:flutter/material.dart';

class NavigationProvider with ChangeNotifier {
  int _index = 0;

  int get index => _index;

  void setIndex(int newIndex) {
    if (newIndex == _index) return;
    _index = newIndex;
    notifyListeners();
  }
}


