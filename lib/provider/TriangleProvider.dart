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
    _applyConstraints();
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

    // Update the tapped triangle and its shared neighbor (edge-sharing rule)
    _setEdgeValue(row, idx, edgeIdx, value);
    final mirror = _sharedEdge(row, idx, edgeIdx);
    if (mirror != null) {
      _setEdgeValue(mirror[0], mirror[1], mirror[2], value);
    }

    // Re-derive auto-disable (-1) marks based on cell + vertex constraints
    _applyConstraints();

    // Update submit data
    submit = _readSubmit();
    notifyListeners();

    // Check completion
    _checkComplete();
  }

  int _getEdge(int row, int idx, int edgeIdx) {
    switch (edgeIdx) {
      case 0: return puzzle[row][idx].edge0;
      case 1: return puzzle[row][idx].edge1;
      case 2: return puzzle[row][idx].edge2;
    }
    return 0;
  }

  /// Constraint propagation entry point. Wipes prior auto-disables (-1) and
  /// then iterates the cell rule and vertex-degree rule until a fixed point.
  /// User annotations (-2, -4) are preserved throughout.
  void _applyConstraints() {
    // Step 1: wipe prior -1 so rules can re-evaluate cleanly.
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < triPerRow; i++) {
        for (int e = 0; e < 3; e++) {
          if (_getEdge(r, i, e) == -1) _setEdgeValue(r, i, e, 0);
        }
      }
    }

    // Step 2: iterate rules until no more changes (or iteration cap).
    for (int iter = 0; iter < 30; iter++) {
      bool changed = false;
      if (_runCellRule()) changed = true;
      if (_runVertexRule()) changed = true;
      if (!changed) break;
    }
  }

  /// Cell rule: if drawn edge count (value ≥ 1) reaches the clue number,
  /// remaining undecided (value 0) edges become -1.
  bool _runCellRule() {
    bool anyChange = false;
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < triPerRow; i++) {
        final int num = puzzle[r][i].num;
        int active = 0;
        for (int e = 0; e < 3; e++) {
          if (_getEdge(r, i, e) >= 1) active++;
        }
        if (active < num) continue;
        for (int e = 0; e < 3; e++) {
          if (_getEdge(r, i, e) == 0) {
            _setEdgeValue(r, i, e, -1);
            final m = _sharedEdge(r, i, e);
            if (m != null) _setEdgeValue(m[0], m[1], m[2], -1);
            anyChange = true;
          }
        }
      }
    }
    return anyChange;
  }

  /// Vertex-degree rule: a Slitherlink vertex must end at degree 0 or 2.
  /// If two edges at a vertex are already drawn, remaining undecided edges
  /// become -1. If fewer than two edges can possibly be drawn (active +
  /// undecided < 2), the remaining undecided edges also become -1.
  bool _runVertexRule() {
    bool anyChange = false;
    for (int vr = 0; vr <= rows; vr++) {
      for (int vc = 0; vc <= cols; vc++) {
        final edges = _incidentEdges(vr, vc);
        if (edges.isEmpty) continue;

        int active = 0, undecided = 0;
        for (final e in edges) {
          final v = _getEdge(e[0], e[1], e[2]);
          if (v >= 1) {
            active++;
          } else if (v == 0) {
            undecided++;
          }
        }

        final bool satisfied = active >= 2;
        final bool starved = active + undecided < 2;
        if (!satisfied && !starved) continue;

        for (final e in edges) {
          if (_getEdge(e[0], e[1], e[2]) == 0) {
            _setEdgeValue(e[0], e[1], e[2], -1);
            final m = _sharedEdge(e[0], e[1], e[2]);
            if (m != null) _setEdgeValue(m[0], m[1], m[2], -1);
            anyChange = true;
          }
        }
      }
    }
    return anyChange;
  }

  /// Return one (row, idx, edgeIdx) representative per unique edge incident
  /// to grid vertex v(vr, vc). Up to six edges for interior vertices; fewer
  /// at boundaries. Picks whichever adjacent triangle is in bounds.
  List<List<int>> _incidentEdges(int vr, int vc) {
    final List<List<int>> out = [];

    // v(vr,vc) → v(vr, vc-1): horizontal to the left
    if (vc > 0) {
      if (vr < rows) {
        out.add([vr, 2 * (vc - 1), 0]);          // Up(vr, 2(vc-1)).e0
      } else if (vr > 0) {
        out.add([vr - 1, 2 * vc - 1, 1]);        // Down(vr-1, 2vc-1).e1
      }
    }
    // v(vr,vc) → v(vr, vc+1): horizontal to the right
    if (vc < cols) {
      if (vr < rows) {
        out.add([vr, 2 * vc, 0]);                // Up(vr, 2vc).e0
      } else if (vr > 0) {
        out.add([vr - 1, 2 * vc + 1, 1]);        // Down(vr-1, 2vc+1).e1
      }
    }
    // v(vr,vc) → v(vr-1, vc): vertical upward
    if (vr > 0) {
      if (vc < cols) {
        out.add([vr - 1, 2 * vc, 2]);            // Up(vr-1, 2vc).e2
      } else if (vc > 0) {
        out.add([vr - 1, 2 * vc - 1, 2]);        // Down(vr-1, 2vc-1).e2
      }
    }
    // v(vr,vc) → v(vr+1, vc): vertical downward
    if (vr < rows) {
      if (vc < cols) {
        out.add([vr, 2 * vc, 2]);                // Up(vr, 2vc).e2
      } else if (vc > 0) {
        out.add([vr, 2 * vc - 1, 2]);            // Down(vr, 2vc-1).e2
      }
    }
    // v(vr,vc) → v(vr-1, vc+1): diagonal up-right
    if (vr > 0 && vc < cols) {
      out.add([vr - 1, 2 * vc, 1]);              // Up(vr-1, 2vc).e1
    }
    // v(vr,vc) → v(vr+1, vc-1): diagonal down-left
    if (vr < rows && vc > 0) {
      out.add([vr, 2 * (vc - 1), 1]);            // Up(vr, 2(vc-1)).e1
    }

    return out;
  }

  /// Write a single triangle-local edge value without side effects.
  void _setEdgeValue(int row, int idx, int edgeIdx, int value) {
    switch (edgeIdx) {
      case 0: puzzle[row][idx].edge0 = value; break;
      case 1: puzzle[row][idx].edge1 = value; break;
      case 2: puzzle[row][idx].edge2 = value; break;
    }
  }

  /// Map a triangle-local edge to the neighbouring triangle's equivalent edge,
  /// following `TriangleGenerator` vertex semantics:
  ///   Up(r, 2c):   e0=(TL,TR) top,  e1=(TR,BL) diagonal, e2=(TL,BL) left
  ///   Down(r,2c+1):e0=(TR,BL) diag, e1=(BL,BR) bottom,   e2=(TR,BR) right
  /// Returns [row, idx, edgeIdx] of the shared neighbour, or null on boundary.
  List<int>? _sharedEdge(int row, int idx, int edgeIdx) {
    final bool isUp = idx % 2 == 0;
    final int c = idx ~/ 2;
    if (isUp) {
      switch (edgeIdx) {
        case 0: // top horizontal ↔ Down(r-1, 2c+1).e1 (bottom horizontal of above-down)
          if (row - 1 >= 0) return [row - 1, 2 * c + 1, 1];
          return null;
        case 1: // diagonal ↔ Down(r, 2c+1).e0
          return [row, 2 * c + 1, 0];
        case 2: // left vertical ↔ Down(r, 2c-1).e2
          if (c > 0) return [row, 2 * c - 1, 2];
          return null;
      }
    } else {
      switch (edgeIdx) {
        case 0: // diagonal ↔ Up(r, 2c).e1
          return [row, 2 * c, 1];
        case 1: // bottom horizontal ↔ Up(r+1, 2c).e0
          if (row + 1 < rows) return [row + 1, 2 * c, 0];
          return null;
        case 2: // right vertical ↔ Up(r, 2(c+1)).e2
          if (c + 1 < cols) return [row, 2 * (c + 1), 2];
          return null;
      }
    }
    return null;
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
    _applyConstraints();
    notifyListeners();
  }

  Future<void> redo() async {
    if (_redoStack.isEmpty) return;
    _undoStack.add(submit.map((r) => List<int>.from(r)).toList());
    submit = _redoStack.removeLast();
    _applySubmit();
    _applyConstraints();
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
    _applyConstraints();
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
            _setEdgeValue(r, i, e, -3);
            final mirror = _sharedEdge(r, i, e);
            if (mirror != null) {
              _setEdgeValue(mirror[0], mirror[1], mirror[2], -3);
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
