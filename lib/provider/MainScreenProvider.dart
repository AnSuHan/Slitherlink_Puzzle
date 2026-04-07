// ignore_for_file: file_names
import 'package:flutter/material.dart';

import '../widgets/MainUI.dart';

/// Provider for main screen UI state to avoid full MaterialApp rebuilds
class MainScreenProvider with ChangeNotifier {
  String _selectedSize = MainUI.selectedType[1];
  String _selectedDifficulty = MainUI.selectedDifficulty;
  int _generateRows = MainUI.generateRows;
  int _generateCols = MainUI.generateCols;
  String _progressKey = MainUI.progressKey;

  String get selectedSize => _selectedSize;
  String get selectedDifficulty => _selectedDifficulty;
  int get generateRows => _generateRows;
  int get generateCols => _generateCols;
  String get progressKey => _progressKey;

  void setSize(String size) {
    _selectedSize = size;
    MainUI.selectedType[1] = size;
    notifyListeners();
  }

  void setDifficulty(String difficulty) {
    _selectedDifficulty = difficulty;
    MainUI.selectedDifficulty = difficulty;
    notifyListeners();
  }

  void setRows(int rows) {
    _generateRows = rows.clamp(5, 20);
    MainUI.generateRows = _generateRows;
    notifyListeners();
  }

  void setCols(int cols) {
    _generateCols = cols.clamp(5, 20);
    MainUI.generateCols = _generateCols;
    notifyListeners();
  }

  void setProgressKey(String key) {
    _progressKey = key;
    MainUI.progressKey = key;
    notifyListeners();
  }

  /// Notify without changing state (for external updates like continue list)
  void refresh() {
    notifyListeners();
  }
}
