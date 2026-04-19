// ignore_for_file: file_names
import 'dart:convert';

import 'package:flutter/material.dart';

import '../Platform/ExtractData.dart'
  if (dart.library.html) '../Platform/ExtractDataWeb.dart';
import '../ThemeColor.dart';
import '../User/UserInfo.dart';
import '../l10n/app_localizations.dart';
import '../widgets/MainUI.dart';
import '../widgets/TriangleBox.dart';

/// State + constraint engine for the equilateral-triangle zigzag Slitherlink.
///
/// The geometry is shared with `TrianglePuzzle` / `TriangleGenerator`:
///   • `isUp(r, i) = (r + i).isEven` — orientation flips every row AND column,
///     giving the ▲▽▲▽ / ▽▲▽▲ zigzag that tiles without gaps.
///   • Vertex grid: v(vr, vi) with `vi ∈ [0, triPerRow + 1]`, positioned at
///     `(vi * w/2, vr * h)`. A vertex exists only when `vr + vi` is odd.
///   • Edge indices (matching the painter):
///       Up:   e0=base,   e1=left-diagonal, e2=right-diagonal
///       Down: e0=top,    e1=left-diagonal, e2=right-diagonal
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

  bool isUp(int row, int idx) => (row + idx).isEven;

  /// puzzle[row][idx] = TriangleBox widget
  List<List<TriangleBox>> puzzle = [];

  /// Answer edge data: answer[row] has triPerRow*3 ints (3 edges per triangle)
  late List<List<int>> answer;
  /// User's current submission (same format as answer)
  late List<List<int>> submit;

  /// Widget list for display
  List<Widget> triangleField = [];

  /// Undo/redo stacks
  final List<List<List<int>>> _undoStack = [];
  final List<List<List<int>>> _redoStack = [];

  void setAnswer(List<List<int>> answer) {
    this.answer = answer;
    rows = answer.length;
    cols = answer[0].length ~/ 6; // triPerRow * 3 = 6 * cols
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
      final List<TriangleBox> row = [];
      for (int i = 0; i < triPerRow; i++) {
        final TriangleBox box = TriangleBox(row: r, idx: i, isUp: isUp(r, i));
        row.add(box);
      }
      puzzle.add(row);
    }

    _setNumbers();
    if (isContinue) _applySubmit();

    // Equilateral zigzag layout: triangle (r, i) occupies the box at
    // (i * w/2, r * h). Overlap between Up and Down at adjacent i is handled
    // by the painter's hitTest so taps on triangle-exterior pixels fall
    // through to the underlying neighbour.
    const double w = TriangleBoxState.cellSize;
    const double h = TriangleBoxState.cellSize * TriangleBoxState.heightRatio;
    final double stackWidth = (triPerRow + 1) * w / 2;
    final double stackHeight = rows * h;

    final List<Widget> positioned = [];
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < triPerRow; i++) {
        positioned.add(Positioned(
          left: i * w / 2,
          top: r * h,
          width: w,
          height: h,
          child: puzzle[r][i],
        ));
      }
    }

    triangleField.add(SizedBox(
      width: stackWidth,
      height: stackHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: positioned,
      ),
    ));
  }

  void _setNumbers() {
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < triPerRow; i++) {
        int count = 0;
        final int base = i * 3;
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
        final int base = i * 3;
        puzzle[r][i].edge0 = submit[r][base];
        puzzle[r][i].edge1 = submit[r][base + 1];
        puzzle[r][i].edge2 = submit[r][base + 2];
      }
    }
  }

  List<List<int>> _readSubmit() {
    final List<List<int>> result = [];
    for (int r = 0; r < rows; r++) {
      final List<int> rowData = [];
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
    _undoStack.add(submit.map((r) => List<int>.from(r)).toList());
    _redoStack.clear();

    _setEdgeValue(row, idx, edgeIdx, value);
    final mirror = _sharedEdge(row, idx, edgeIdx);
    if (mirror != null) {
      _setEdgeValue(mirror[0], mirror[1], mirror[2], value);
    }

    _applyConstraints();

    submit = _readSubmit();
    notifyListeners();

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
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < triPerRow; i++) {
        for (int e = 0; e < 3; e++) {
          if (_getEdge(r, i, e) == -1) _setEdgeValue(r, i, e, 0);
        }
      }
    }

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
      for (int vi = 0; vi <= triPerRow + 1; vi++) {
        if ((vr + vi).isEven) continue; // only vr+vi odd are real vertices
        final edges = _incidentEdges(vr, vi);
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

  /// One (row, idx, edgeIdx) representative per unique edge incident to v(vr, vi).
  /// Up to six edges for an interior vertex; fewer at the boundary.
  ///
  /// Six possible directions (prefers the "lower/nearer" triangle; falls back
  /// to the other representative when the first is out of bounds):
  ///   1. up-right diagonal  → Up(vr-1, vi).e1      | Down(vr-1, vi-1).e2
  ///   2. right horizontal   → Down(vr, vi).e0      | Up(vr-1, vi).e0
  ///   3. down-right diagonal→ Down(vr, vi).e1      | Up(vr, vi-1).e2
  ///   4. down-left diagonal → Up(vr, vi-1).e1      | Down(vr, vi-2).e2
  ///   5. left horizontal    → Down(vr, vi-2).e0    | Up(vr-1, vi-2).e0
  ///   6. up-left diagonal   → Down(vr-1, vi-1).e1  | Up(vr-1, vi-2).e2
  List<List<int>> _incidentEdges(int vr, int vi) {
    final List<List<int>> out = [];

    // 1. up-right
    if (vr >= 1) {
      if (vi < triPerRow) {
        out.add([vr - 1, vi, 1]);
      } else if (vi - 1 >= 0 && vi - 1 < triPerRow) {
        out.add([vr - 1, vi - 1, 2]);
      }
    }

    // 2. right horizontal
    if (vi + 2 <= triPerRow + 1) {
      if (vr < rows && vi < triPerRow) {
        out.add([vr, vi, 0]);
      } else if (vr >= 1 && vi < triPerRow) {
        out.add([vr - 1, vi, 0]);
      }
    }

    // 3. down-right
    if (vr < rows) {
      if (vi < triPerRow) {
        out.add([vr, vi, 1]);
      } else if (vi - 1 >= 0 && vi - 1 < triPerRow) {
        out.add([vr, vi - 1, 2]);
      }
    }

    // 4. down-left
    if (vr < rows && vi >= 1) {
      if (vi - 1 < triPerRow) {
        out.add([vr, vi - 1, 1]);
      } else if (vi - 2 >= 0 && vi - 2 < triPerRow) {
        out.add([vr, vi - 2, 2]);
      }
    }

    // 5. left horizontal
    if (vi >= 2) {
      if (vr < rows && vi - 2 < triPerRow) {
        out.add([vr, vi - 2, 0]);
      } else if (vr >= 1 && vi - 2 < triPerRow) {
        out.add([vr - 1, vi - 2, 0]);
      }
    }

    // 6. up-left
    if (vr >= 1 && vi >= 1) {
      if (vi - 1 < triPerRow) {
        out.add([vr - 1, vi - 1, 1]);
      } else if (vi - 2 >= 0 && vi - 2 < triPerRow) {
        out.add([vr - 1, vi - 2, 2]);
      }
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

  /// Map a triangle-local edge to the neighbouring triangle's equivalent edge.
  /// Geometry (matches the painter, `isUp = (r+i).isEven`):
  ///   Up:   e0=base  (r+1 side) ↔ Down(r+1, i).e0
  ///         e1=left-diag         ↔ Down(r, i-1).e2
  ///         e2=right-diag        ↔ Down(r, i+1).e1
  ///   Down: e0=top   (r-1 side) ↔ Up(r-1, i).e0
  ///         e1=left-diag         ↔ Up(r, i-1).e2
  ///         e2=right-diag        ↔ Up(r, i+1).e1
  /// Returns null when the neighbour is off-grid.
  List<int>? _sharedEdge(int row, int idx, int edgeIdx) {
    if (isUp(row, idx)) {
      switch (edgeIdx) {
        case 0:
          if (row + 1 < rows) return [row + 1, idx, 0];
          return null;
        case 1:
          if (idx - 1 >= 0) return [row, idx - 1, 2];
          return null;
        case 2:
          if (idx + 1 < triPerRow) return [row, idx + 1, 1];
          return null;
      }
    } else {
      switch (edgeIdx) {
        case 0:
          if (row - 1 >= 0) return [row - 1, idx, 0];
          return null;
        case 1:
          if (idx - 1 >= 0) return [row, idx - 1, 2];
          return null;
        case 2:
          if (idx + 1 < triPerRow) return [row, idx + 1, 1];
          return null;
      }
    }
    return null;
  }

  void _checkComplete() {
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < triPerRow; i++) {
        final int base = i * 3;
        for (int e = 0; e < 3; e++) {
          final int ansVal = answer[r][base + e];
          final int subVal = submit[r][base + e];
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

  Future<void> saveProgress() async {
    submit = _readSubmit();
    final prefs = ExtractData();
    await prefs.saveDataToLocal("${MainUI.getProgressKey()}_continue", jsonEncode(submit));
  }

  Future<void> showHint(BuildContext context) async {
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < triPerRow; i++) {
        final int base = i * 3;
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
