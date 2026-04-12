// ignore_for_file: file_names
import 'dart:convert';

import 'package:flutter/material.dart';

import '../MakePuzzle/HexagonGenerator.dart';
import '../Platform/ExtractData.dart'
  if (dart.library.html) '../Platform/ExtractDataWeb.dart';
import '../ThemeColor.dart';
import '../User/UserInfo.dart';
import '../l10n/app_localizations.dart';
import '../widgets/MainUI.dart';
import '../widgets/HexagonBox.dart';

class HexagonProvider with ChangeNotifier {
  late BuildContext context;
  final String loadKey;
  bool shutdown = false;
  bool isContinue = false;

  HexagonProvider({
    this.isContinue = false,
    required this.context,
    required this.loadKey,
  });

  ThemeColor themeColor = ThemeColor();

  int rows = 0;
  int cols = 0;

  /// puzzle[row][col] = HexagonBox widget
  List<List<HexagonBox>> puzzle = [];

  /// Answer edge data: answer[row] has cols*6 ints (6 edges per hexagon)
  late List<List<int>> answer;
  /// User's current submission (same format as answer)
  late List<List<int>> submit;

  /// Widget list for display
  List<Widget> hexagonField = [];

  /// Undo/redo stacks
  List<List<List<int>>> _undoStack = [];
  List<List<List<int>>> _redoStack = [];

  void setAnswer(List<List<int>> answer) {
    this.answer = answer;
    rows = answer.length;
    cols = answer[0].length ~/ 6;
  }

  void setSubmit(List<List<int>> submit) {
    this.submit = submit;
  }

  Future<void> init() async {
    _buildPuzzle();
    notifyListeners();
  }

  void _buildPuzzle() {
    puzzle = [];
    hexagonField = [];

    for (int r = 0; r < rows; r++) {
      List<HexagonBox> row = [];
      for (int c = 0; c < cols; c++) {
        HexagonBox box = HexagonBox(row: r, col: c);
        row.add(box);
      }
      puzzle.add(row);
    }

    // Set numbers from answer
    _setNumbers();

    // Apply submit if continuing
    if (isContinue) {
      _applySubmit();
    }

    // Build widget tree with hex grid layout
    final double hexR = HexagonBoxState.cellSize;
    final double hexW = hexR * 2;
    final double hexH = hexR * 1.732; // sqrt(3)

    for (int r = 0; r < rows; r++) {
      bool isOddRow = r % 2 == 1;
      double offsetX = isOddRow ? hexR : 0;

      List<Widget> rowChildren = [];
      if (isOddRow) {
        rowChildren.add(SizedBox(width: offsetX));
      }
      for (int c = 0; c < cols; c++) {
        rowChildren.add(puzzle[r][c]);
        // Small gap between hexagons
        if (c < cols - 1) {
          rowChildren.add(const SizedBox(width: 2));
        }
      }

      hexagonField.add(Transform.translate(
        offset: Offset(0, -r * hexH * 0.25), // Overlap rows for hex tiling
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: rowChildren,
        ),
      ));
    }
  }

  void _setNumbers() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        int count = 0;
        int base = c * 6;
        for (int e = 0; e < 6; e++) {
          if (answer[r][base + e] == 1) count++;
        }
        puzzle[r][c].num = count;
      }
    }
  }

  void _applySubmit() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        int base = c * 6;
        for (int e = 0; e < 6; e++) {
          puzzle[r][c].edges[e] = submit[r][base + e];
        }
      }
    }
  }

  List<List<int>> _readSubmit() {
    List<List<int>> result = [];
    for (int r = 0; r < rows; r++) {
      List<int> rowData = [];
      for (int c = 0; c < cols; c++) {
        for (int e = 0; e < 6; e++) {
          rowData.add(puzzle[r][c].edges[e]);
        }
      }
      result.add(rowData);
    }
    return result;
  }

  List<Widget> getHexagonField() => hexagonField;

  /// Called when user taps an edge
  Future<void> updateEdge(int row, int col, int edgeIdx, int value) async {
    _undoStack.add(submit.map((r) => List<int>.from(r)).toList());
    _redoStack.clear();

    puzzle[row][col].edges[edgeIdx] = value;
    submit = _readSubmit();
    notifyListeners();

    _checkComplete();
  }

  void _checkComplete() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        int base = c * 6;
        for (int e = 0; e < 6; e++) {
          int ansVal = answer[r][base + e];
          int subVal = submit[r][base + e];
          if (ansVal == 1 && subVal <= 0) return;
          if (ansVal == 0 && subVal >= 1) return;
        }
      }
    }

    showComplete(context);
  }

  Future<void> showComplete(BuildContext context) async {
    shutdown = true;
    UserInfo.incrementCompleted(loadKey);
    UserInfo.clearPuzzle(loadKey);

    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(loc?.translate('game_complete_title') ?? 'Complete!'),
        content: Text(loc?.translate('game_complete_message') ?? 'Congratulations!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (Navigator.canPop(context)) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> undo() async {
    if (_undoStack.isEmpty) return;
    _redoStack.add(submit.map((r) => List<int>.from(r)).toList());
    submit = _undoStack.removeLast();
    _applySubmit();
    notifyListeners();
  }

  Future<void> redo() async {
    if (_redoStack.isEmpty) return;
    _undoStack.add(submit.map((r) => List<int>.from(r)).toList());
    submit = _redoStack.removeLast();
    _applySubmit();
    notifyListeners();
  }

  Future<void> restart() async {
    _undoStack.clear();
    _redoStack.clear();
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < submit[r].length; i++) {
        submit[r][i] = 0;
      }
    }
    _applySubmit();
    notifyListeners();
  }

  Future<void> saveProgress() async {
    submit = _readSubmit();
    final prefs = ExtractData();
    await prefs.saveDataToLocal("${MainUI.getProgressKey()}_continue", jsonEncode(submit));
  }

  Future<void> showHint(BuildContext context) async {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        int base = c * 6;
        for (int e = 0; e < 6; e++) {
          if (answer[r][base + e] == 1 && submit[r][base + e] <= 0) {
            puzzle[r][c].edges[e] = -3;
            notifyListeners();
            return;
          }
        }
      }
    }
  }

  Future<void> removeHintLine() async {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        for (int e = 0; e < 6; e++) {
          if (puzzle[r][c].edges[e] == -3 || puzzle[r][c].edges[e] == -5) {
            puzzle[r][c].edges[e] = 0;
          }
        }
      }
    }
  }

  int getBoxColor(int row, int col) => 0;
}
