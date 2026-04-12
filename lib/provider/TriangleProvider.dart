// ignore_for_file: file_names
import 'dart:convert';

import 'package:flutter/material.dart';

import '../MakePuzzle/TriangleGenerator.dart';
import '../Platform/ExtractData.dart'
  if (dart.library.html) '../Platform/ExtractDataWeb.dart';
import '../ThemeColor.dart';
import '../User/UserInfo.dart';
import '../l10n/app_localizations.dart';
import '../widgets/MainUI.dart';
import '../widgets/TriangleBox.dart';

class TriangleProvider with ChangeNotifier {
  late BuildContext context;
  final String loadKey;
  bool shutdown = false;
  bool isContinue = false;

  TriangleProvider({
    this.isContinue = false,
    required this.context,
    required this.loadKey,
  });

  ThemeColor themeColor = ThemeColor();

  int rows = 0;
  int cols = 0;
  int get triPerRow => 2 * cols;

  /// puzzle[row][idx] = TriangleBox widget
  List<List<TriangleBox>> puzzle = [];

  /// Answer edge data: answer[row] has triPerRow*3 ints (3 edges per triangle)
  late List<List<int>> answer;
  /// User's current submission (same format as answer)
  late List<List<int>> submit;

  /// Widget list for display
  List<Widget> triangleField = [];

  /// Undo/redo stacks
  List<List<List<int>>> _undoStack = [];
  List<List<List<int>>> _redoStack = [];

  void setAnswer(List<List<int>> answer) {
    this.answer = answer;
    rows = answer.length;
    cols = answer[0].length ~/ 6; // each triangle has 3 edges, 2*cols triangles per row => 6*cols values
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
    triangleField = [];

    for (int r = 0; r < rows; r++) {
      List<TriangleBox> row = [];
      for (int i = 0; i < triPerRow; i++) {
        bool isUp = i % 2 == 0;
        TriangleBox box = TriangleBox(row: r, idx: i, isUp: isUp);
        row.add(box);
      }
      puzzle.add(row);
    }

    // Apply answer to set numbers
    _setNumbers();

    // Apply submit state if continuing
    if (isContinue) {
      _applySubmit();
    }

    // Build widget tree
    for (int r = 0; r < rows; r++) {
      List<Widget> rowChildren = [];
      for (int i = 0; i < triPerRow; i++) {
        bool isUp = i % 2 == 0;
        rowChildren.add(Transform.translate(
          offset: Offset(0, isUp ? 0 : -TriangleBoxState.cellSize * 0.866 * 0.0),
          child: puzzle[r][i],
        ));
      }
      triangleField.add(Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: rowChildren,
      ));
    }
  }

  void _setNumbers() {
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < triPerRow; i++) {
        // Count active answer edges for this triangle
        int count = 0;
        int base = i * 3;
        for (int e = 0; e < 3; e++) {
          if (answer[r][base + e] == 1) count++;
        }
        puzzle[r][i].num = count;
      }
    }
  }

  void _applySubmit() {
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < triPerRow; i++) {
        int base = i * 3;
        puzzle[r][i].edge0 = submit[r][base];
        puzzle[r][i].edge1 = submit[r][base + 1];
        puzzle[r][i].edge2 = submit[r][base + 2];
      }
    }
  }

  /// Read current state from puzzle widgets
  List<List<int>> _readSubmit() {
    List<List<int>> result = [];
    for (int r = 0; r < rows; r++) {
      List<int> rowData = [];
      for (int i = 0; i < triPerRow; i++) {
        rowData.add(puzzle[r][i].edge0);
        rowData.add(puzzle[r][i].edge1);
        rowData.add(puzzle[r][i].edge2);
      }
      result.add(rowData);
    }
    return result;
  }

  List<Widget> getTriangleField() => triangleField;

  /// Called when user taps an edge
  Future<void> updateEdge(int row, int idx, int edgeIdx, int value) async {
    // Save undo state
    _undoStack.add(submit.map((r) => List<int>.from(r)).toList());
    _redoStack.clear();

    // Update the puzzle widget
    switch (edgeIdx) {
      case 0: puzzle[row][idx].edge0 = value; break;
      case 1: puzzle[row][idx].edge1 = value; break;
      case 2: puzzle[row][idx].edge2 = value; break;
    }

    // Update submit data
    submit = _readSubmit();
    notifyListeners();

    // Check completion
    _checkComplete();
  }

  void _checkComplete() {
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < triPerRow; i++) {
        int base = i * 3;
        for (int e = 0; e < 3; e++) {
          int ansVal = answer[r][base + e];
          int subVal = submit[r][base + e];
          // Answer edge is 1, submit must be >= 1 (any color)
          if (ansVal == 1 && subVal <= 0) return;
          // Answer edge is 0, submit must be <= 0 (not drawn)
          if (ansVal == 0 && subVal >= 1) return;
        }
      }
    }

    // Puzzle complete!
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

  /// Save progress
  Future<void> saveProgress() async {
    submit = _readSubmit();
    final prefs = ExtractData();
    await prefs.saveDataToLocal("${MainUI.getProgressKey()}_continue", jsonEncode(submit));
  }

  /// Show hint: find a missing edge and flash it
  Future<void> showHint(BuildContext context) async {
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < triPerRow; i++) {
        int base = i * 3;
        for (int e = 0; e < 3; e++) {
          if (answer[r][base + e] == 1 && submit[r][base + e] <= 0) {
            // Show this edge as hint
            switch (e) {
              case 0: puzzle[r][i].edge0 = -3; break;
              case 1: puzzle[r][i].edge1 = -3; break;
              case 2: puzzle[r][i].edge2 = -3; break;
            }
            notifyListeners();
            return;
          }
        }
      }
    }
  }

  Future<void> removeHintLine() async {
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < triPerRow; i++) {
        if (puzzle[r][i].edge0 == -3 || puzzle[r][i].edge0 == -5) puzzle[r][i].edge0 = 0;
        if (puzzle[r][i].edge1 == -3 || puzzle[r][i].edge1 == -5) puzzle[r][i].edge1 = 0;
        if (puzzle[r][i].edge2 == -3 || puzzle[r][i].edge2 == -5) puzzle[r][i].edge2 = 0;
      }
    }
  }

  int getBoxColor(int row, int idx) => 0;
}
