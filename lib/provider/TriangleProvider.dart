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
  /// Clue data: clue[row][idx] holds the displayed hint number; `-1` means the
  /// clue is hidden (no number drawn, and no cell-rule constraint applied).
  late List<List<int>> clue;
  /// User's current submission (same format as answer)
  late List<List<int>> submit;

  /// Widget list for display
  List<Widget> triangleField = [];

  /// Undo/redo stacks
  final List<List<List<int>>> _undoStack = [];
  final List<List<List<int>>> _redoStack = [];

  /// Canvas position (inside InteractiveViewer's child, including the
  /// scene's outer Padding(20)) of the most recently placed hint, or null
  /// if no hint is currently active.
  Offset? _hintCanvasPos;
  Offset? getHintCanvasPos() => _hintCanvasPos;

  /// Canvas-space midpoint of edge `e` of triangle (r, i). Mirrors
  /// `_buildPuzzle`: each triangle's box top-left is at
  /// (i·w/2, r·h) inside a Stack wrapped in Padding(20).
  Offset _triEdgeMidpoint(int r, int i, int e) {
    const double w = TriangleBoxState.cellSize;
    const double h = TriangleBoxState.cellSize * TriangleBoxState.heightRatio;
    const double scenePadding = 20.0;
    final double bx = scenePadding + i * w / 2;
    final double by = scenePadding + r * h;
    final bool up = isUp(r, i);
    // See painter `vertices`/edge layout:
    //   Up:   e0 base (p1-p2), e1 left (p0-p1), e2 right (p0-p2)
    //   Down: e0 top (p0-p1),  e1 left (p0-p2), e2 right (p1-p2)
    if (up) {
      switch (e) {
        case 0: return Offset(bx + w / 2, by + h);     // base
        case 1: return Offset(bx + w / 4, by + h / 2); // left
        case 2: return Offset(bx + 3 * w / 4, by + h / 2);
      }
    } else {
      switch (e) {
        case 0: return Offset(bx + w / 2, by);
        case 1: return Offset(bx + w / 4, by + h / 2);
        case 2: return Offset(bx + 3 * w / 4, by + h / 2);
      }
    }
    return Offset(bx + w / 2, by + h / 2);
  }

  void setAnswer(List<List<int>> answer) {
    this.answer = answer;
    rows = answer.length;
    cols = answer[0].length ~/ 6; // triPerRow * 3 = 6 * cols
  }

  void setClue(List<List<int>> clue) {
    this.clue = clue;
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
        // `clue[r][i]` is -1 when the hint is hidden by difficulty.
        puzzle[r][i].num = clue[r][i];
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
  /// then iterates the cell rule and vertex-degree rule until a fixed point,
  /// followed by a 1-step look-ahead pass: each undecided edge is hypothetically
  /// drawn and propagated; if the hypothesis triggers a contradiction (a clue
  /// would over-fill, or a vertex would exceed degree 2) the edge is flagged
  /// -1.
  ///
  /// User red marks (-2) are also cleared to 0 alongside -1 so look-ahead
  /// doesn't lock them as hard premises (which would cascade-disable
  /// adjacent edges). After propagation, -2 is restored at positions whose
  /// new value is -1. User X marks (-4) are hard locks and not touched.
  ///
  /// Global-infeasibility guard: if the user X-marks a critical drawn line,
  /// the puzzle becomes globally infeasible; look-ahead would then mark
  /// every undecided edge -1 and wipe the board. We snapshot the full
  /// edge grid at entry and restore it if the post-propagation state is
  /// inconsistent. See docs/constraint_lookahead.md §4 / §5.
  void _applyConstraints() {
    final List<List<List<int>>> guardSnap = List.generate(rows, (rr) =>
        List.generate(triPerRow, (ii) => [
              puzzle[rr][ii].edge0,
              puzzle[rr][ii].edge1,
              puzzle[rr][ii].edge2,
            ]));

    final List<List<int>> redSnapshot = [];
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < triPerRow; i++) {
        for (int e = 0; e < 3; e++) {
          final v = _getEdge(r, i, e);
          if (v == -1) {
            _setEdgeValue(r, i, e, 0);
          } else if (v == -2) {
            redSnapshot.add([r, i, e]);
            _setEdgeValue(r, i, e, 0);
          }
        }
      }
    }

    // Capture consistency AFTER clearing so it reflects what propagation sees.
    // Only revert when propagation TURNED a previously-OK state into an
    // inconsistent one (e.g. critical X-mark + look-ahead wiping). If the
    // user over-drew a clue cell, direct-rule cascade is local and gives
    // useful "you can't draw here" feedback — we keep those results.
    final bool entryConsistent = _isStateConsistent();

    _propagateDirect();
    for (int laIter = 0; laIter < 5; laIter++) {
      if (!_runLookAhead()) break;
      _propagateDirect();
    }

    for (final pos in redSnapshot) {
      if (_getEdge(pos[0], pos[1], pos[2]) == -1) {
        _setEdgeValue(pos[0], pos[1], pos[2], -2);
        final m = _sharedEdge(pos[0], pos[1], pos[2]);
        if (m != null && _getEdge(m[0], m[1], m[2]) == -1) {
          _setEdgeValue(m[0], m[1], m[2], -2);
        }
      }
    }

    if (entryConsistent && !_isStateConsistent()) {
      for (int rr = 0; rr < rows; rr++) {
        for (int ii = 0; ii < triPerRow; ii++) {
          puzzle[rr][ii].edge0 = guardSnap[rr][ii][0];
          puzzle[rr][ii].edge1 = guardSnap[rr][ii][1];
          puzzle[rr][ii].edge2 = guardSnap[rr][ii][2];
        }
      }
    }
  }

  void _propagateDirect() {
    for (int iter = 0; iter < 30; iter++) {
      bool changed = false;
      if (_runCellRule()) changed = true;
      if (_runVertexRule()) changed = true;
      if (!changed) break;
    }
  }

  /// Cell rule: if drawn edge count (value ≥ 1) reaches the clue number,
  /// remaining undecided (value 0) edges become -1. Hidden clues (`num < 0`)
  /// carry no constraint and are skipped.
  bool _runCellRule() {
    bool anyChange = false;
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < triPerRow; i++) {
        final int num = puzzle[r][i].num;
        if (num < 0) continue;
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

  /// Returns canonical id for an edge so shared edges resolve to a single
  /// representative (used by look-ahead to avoid double-testing).
  int _canonicalEdgeId(int r, int i, int e) {
    final selfId = (r * 1000 + i) * 10 + e;
    final m = _sharedEdge(r, i, e);
    if (m == null) return selfId;
    final otherId = (m[0] * 1000 + m[1]) * 10 + m[2];
    return selfId <= otherId ? selfId : otherId;
  }

  /// Returns true iff the live puzzle state already violates a hard
  /// constraint. See HexagonProvider._isStateConsistent for the rationale.
  bool _isStateConsistent() {
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < triPerRow; i++) {
        final num = puzzle[r][i].num;
        if (num < 0) continue;
        int active = 0, undecided = 0;
        for (int e = 0; e < 3; e++) {
          final v = _getEdge(r, i, e);
          if (v >= 1) {
            active++;
          } else if (v == 0) {
            undecided++;
          }
        }
        if (active > num) return false;
        if (active + undecided < num) return false;
      }
    }
    for (int vr = 0; vr <= rows; vr++) {
      for (int vi = 0; vi <= triPerRow + 1; vi++) {
        if ((vr + vi).isEven) continue;
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
        if (active > 2) return false;
        if (active == 1 && undecided == 0) return false;
      }
    }
    return true;
  }

  /// Look-ahead pass. For each undecided edge: snapshot the grid, hypothesise
  /// the edge as drawn (=1), run a hypothetical propagator that adds force-draw
  /// rules and contradiction detection, then restore. If the hypothesis broke
  /// a clue or vertex constraint, the actual edge is flagged -1.
  bool _runLookAhead() {
    if (!_isStateConsistent()) return false;
    bool anyChange = false;
    final Set<int> tested = {};
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < triPerRow; i++) {
        for (int e = 0; e < 3; e++) {
          if (_getEdge(r, i, e) != 0) continue;
          final canonical = _canonicalEdgeId(r, i, e);
          if (!tested.add(canonical)) continue;

          final snap = List.generate(rows, (rr) =>
              List.generate(triPerRow, (ii) => [
                puzzle[rr][ii].edge0,
                puzzle[rr][ii].edge1,
                puzzle[rr][ii].edge2,
              ]));

          _setEdgeValue(r, i, e, 1);
          final m = _sharedEdge(r, i, e);
          if (m != null) _setEdgeValue(m[0], m[1], m[2], 1);

          final contradiction = _propagateHypothesis();

          for (int rr = 0; rr < rows; rr++) {
            for (int ii = 0; ii < triPerRow; ii++) {
              _setEdgeValue(rr, ii, 0, snap[rr][ii][0]);
              _setEdgeValue(rr, ii, 1, snap[rr][ii][1]);
              _setEdgeValue(rr, ii, 2, snap[rr][ii][2]);
            }
          }

          if (contradiction) {
            _setEdgeValue(r, i, e, -1);
            if (m != null) _setEdgeValue(m[0], m[1], m[2], -1);
            anyChange = true;
          }
        }
      }
    }
    return anyChange;
  }

  /// Hypothetical propagator used inside _runLookAhead. Mutates puzzle.edges
  /// freely — caller must snapshot+restore. Returns true on contradiction.
  bool _propagateHypothesis() {
    for (int iter = 0; iter < 30; iter++) {
      bool changed = false;

      for (int r = 0; r < rows; r++) {
        for (int i = 0; i < triPerRow; i++) {
          final num = puzzle[r][i].num;
          if (num < 0) continue;
          int active = 0, undecided = 0;
          for (int e = 0; e < 3; e++) {
            final v = _getEdge(r, i, e);
            if (v >= 1) {
              active++;
            } else if (v == 0) {
              undecided++;
            }
          }
          if (active > num) return true;
          if (active + undecided < num) return true;
          if (active == num && undecided > 0) {
            for (int e = 0; e < 3; e++) {
              if (_getEdge(r, i, e) == 0) {
                _setEdgeValue(r, i, e, -1);
                final m = _sharedEdge(r, i, e);
                if (m != null) _setEdgeValue(m[0], m[1], m[2], -1);
                changed = true;
              }
            }
          } else if (active + undecided == num && undecided > 0) {
            for (int e = 0; e < 3; e++) {
              if (_getEdge(r, i, e) == 0) {
                _setEdgeValue(r, i, e, 1);
                final m = _sharedEdge(r, i, e);
                if (m != null) _setEdgeValue(m[0], m[1], m[2], 1);
                changed = true;
              }
            }
          }
        }
      }

      for (int vr = 0; vr <= rows; vr++) {
        for (int vi = 0; vi <= triPerRow + 1; vi++) {
          if ((vr + vi).isEven) continue;
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
          if (active > 2) return true;
          if (active == 1 && undecided == 0) return true;

          if (active >= 2 && undecided > 0) {
            for (final e in edges) {
              if (_getEdge(e[0], e[1], e[2]) == 0) {
                _setEdgeValue(e[0], e[1], e[2], -1);
                final m = _sharedEdge(e[0], e[1], e[2]);
                if (m != null) _setEdgeValue(m[0], m[1], m[2], -1);
                changed = true;
              }
            }
          } else if (active == 0 && undecided > 0 && undecided < 2) {
            for (final e in edges) {
              if (_getEdge(e[0], e[1], e[2]) == 0) {
                _setEdgeValue(e[0], e[1], e[2], -1);
                final m = _sharedEdge(e[0], e[1], e[2]);
                if (m != null) _setEdgeValue(m[0], m[1], m[2], -1);
                changed = true;
              }
            }
          } else if (active == 1 && undecided == 1) {
            for (final e in edges) {
              if (_getEdge(e[0], e[1], e[2]) == 0) {
                _setEdgeValue(e[0], e[1], e[2], 1);
                final m = _sharedEdge(e[0], e[1], e[2]);
                if (m != null) _setEdgeValue(m[0], m[1], m[2], 1);
                changed = true;
              }
            }
          }
        }
      }

      if (!changed) break;
    }
    return false;
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
    // 자동 풀기 중이었다면 먼저 중단 — restart 가 puzzle 을 비우는데
    // 솔버 루프가 살아 있으면 다음 iter 가 비워진 보드 위에 추론 결과를
    // 다시 덮어쓴다. SquareProvider.restart 와 동일한 가드.
    if (_solverRunning) {
      _solverShouldStop = true;
      while (_solverRunning) {
        await Future.delayed(const Duration(milliseconds: 30));
      }
    }
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
    // Hint (-3) and wrong-flash (-5) markers are ephemeral — drop them
    // before persisting so Continue doesn't resurrect a stale flash.
    await removeHintLine();
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
            _hintCanvasPos = _triEdgeMidpoint(r, i, e);
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
    _hintCanvasPos = null;
  }

  /// Deep copy of the current submit grid for bookmark save.
  List<List<int>> snapshotSubmit() {
    submit = _readSubmit();
    return submit.map((r) => List<int>.from(r)).toList();
  }

  /// Apply a previously-saved submit grid (from a bookmark load).
  /// Treated as a single edit step: the pre-load state is pushed onto the
  /// undo stack so the user can undo back, and the redo stack is dropped
  /// because we're branching forward from the user's current position.
  Future<void> applyBookmarkSubmit(List<List<int>> newSubmit) async {
    await removeHintLine();
    submit = _readSubmit();
    _undoStack.add(submit.map((r) => List<int>.from(r)).toList());
    _redoStack.clear();
    submit = newSubmit.map((r) => List<int>.from(r)).toList();
    _applySubmit();
    _applyConstraints();
    submit = _readSubmit();
    notifyListeners();
  }

  int getBoxColor(int row, int idx) => 0;

  ///**********************************************************************************
  ///****************** human-like auto solver ******************
  ///**********************************************************************************
  /// SquareProvider.solveHumanLike 와 동일한 골격으로, 매 iter 한 수씩 100%
  /// 확정 라인 (forced-draw / forced-disable) 을 찾아 사용자 탭처럼 그어준다.
  /// 확정이 없으면 영향력이 가장 큰 undecided edge 를 추측 후보로 골라 그어보고,
  /// 모순이 발생하면 직전 추측 시점의 submit 스냅샷으로 복원한 뒤 실패 edge 를
  /// 사용자 X (-4) 로 잠가 같은 분기를 다시 시도하지 않게 한다. 추측 슬롯은
  /// 최대 3 단계까지 누적 (Square 의 R/G/B 슬롯과 동일한 깊이). 사용자가
  /// [cancelSolver] 를 호출하거나 restart 하면 즉시 종료한다.
  static const int _solverMaxGuesses = 3;

  bool _solverRunning = false;
  bool _solverShouldStop = false;
  String _solverStatus = "";

  bool get isSolverRunning => _solverRunning;
  String get solverStatus => _solverStatus;

  void cancelSolver() {
    _solverShouldStop = true;
  }

  /// [stepDelay] 한 수와 다음 수 사이의 대기. 기본 0 (지연 없음).
  Future<void> solveHumanLike({Duration stepDelay = Duration.zero}) async {
    if (_solverRunning) return;
    _solverRunning = true;
    _solverShouldStop = false;
    _solverStatus = "solver_running";
    notifyListeners();

    final List<_TriangleGuessFrame> guesses = [];

    try {
      while (!_solverShouldStop) {
        submit = _readSubmit();
        if (_isPuzzleSolvedLocal()) {
          _solverStatus = "solver_done";
          notifyListeners();
          break;
        }

        // 진입 시점 상태가 이미 모순이면 마지막 추측이 잘못된 것.
        if (!_isStateConsistent()) {
          if (!await _backtrackToLastGuess(guesses, stepDelay)) break;
          await Future.delayed(stepDelay);
          continue;
        }

        // "edge=-1 가설 → 모순 → 반드시 +1" 의 확정 +1 추출.
        final List<int>? draw = _findForcedDrawByContradiction();
        if (draw != null) {
          _solverStatus = "solver_step";
          notifyListeners();
          final ok = await _solverApplyAndCheck(
              draw[0], draw[1], draw[2], themeColor.getNormalRandom());
          if (_solverShouldStop) break;
          if (!ok) {
            if (!await _backtrackToLastGuess(guesses, stepDelay)) break;
          }
          await Future.delayed(stepDelay);
          continue;
        }

        // "edge=+1 가설 → 모순 → 반드시 -1" 의 확정 -1 추출. 사용자 X (-4)
        // 로 잠가 _applyConstraints 가 다시 0 으로 풀지 못하게 한다.
        // 이 단계가 없으면 미처리 -1 확정이 _pickHighestImpactGuess 로
        // 흘러들어가 잘못된 +1 으로 그어진다 (docs/auto_solver_bug_analysis.md §1).
        final List<int>? disable = _findForcedDisableByContradiction();
        if (disable != null) {
          _solverStatus = "solver_step";
          notifyListeners();
          final ok = await _solverApplyAndCheck(
              disable[0], disable[1], disable[2], -4);
          if (_solverShouldStop) break;
          if (!ok) {
            if (!await _backtrackToLastGuess(guesses, stepDelay)) break;
          }
          await Future.delayed(stepDelay);
          continue;
        }

        // 확정 없음 → 영향력이 가장 큰 edge 로 추측.
        if (guesses.length >= _solverMaxGuesses) {
          _solverStatus = "solver_labels_full";
          notifyListeners();
          break;
        }
        final List<int>? guess = _pickHighestImpactGuess();
        if (guess == null) {
          _solverStatus = "solver_stuck";
          notifyListeners();
          break;
        }
        final snap =
            _readSubmit().map((r) => List<int>.from(r)).toList();
        guesses.add(_TriangleGuessFrame(snap, guess[0], guess[1], guess[2]));
        _solverStatus = "solver_guess";
        notifyListeners();
        final ok = await _solverApplyAndCheck(
            guess[0], guess[1], guess[2], themeColor.getNormalRandom());
        if (_solverShouldStop) break;
        if (!ok) {
          if (!await _backtrackToLastGuess(guesses, stepDelay)) break;
        }
        await Future.delayed(stepDelay);
      }
    } finally {
      _solverRunning = false;
      notifyListeners();
    }
  }

  bool _isPuzzleSolvedLocal() {
    if (rows == 0 || answer.isEmpty) return false;
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < triPerRow; i++) {
        final int base = i * 3;
        for (int e = 0; e < 3; e++) {
          final bool ansSel = answer[r][base + e] == 1;
          final bool subSel = _getEdge(r, i, e) >= 1;
          if (ansSel != subSel) return false;
        }
      }
    }
    return true;
  }

  /// 마지막 추측 frame 을 pop 해 스냅샷 시점으로 복원하고, 실패 edge 를
  /// 사용자 X (-4) 로 잠가 같은 분기를 다시 시도하지 않게 한다. guesses 가
  /// 비어 있으면 false 를 반환해 호출자가 솔버를 멈추게 한다.
  Future<bool> _backtrackToLastGuess(
      List<_TriangleGuessFrame> guesses, Duration stepDelay) async {
    if (guesses.isEmpty) {
      _solverStatus = "solver_stuck";
      notifyListeners();
      return false;
    }
    final frame = guesses.removeLast();
    _solverStatus = "solver_backtrack";
    notifyListeners();

    // 사용자가 undo 한 번에 추측 직전으로 되돌릴 수 있게 현재 submit 을
    // _undoStack 에 push 한 뒤 스냅샷을 복원한다.
    _undoStack.add(submit.map((r) => List<int>.from(r)).toList());
    _redoStack.clear();
    submit = frame.snapshot.map((r) => List<int>.from(r)).toList();
    _applySubmit();
    _applyConstraints();
    submit = _readSubmit();
    notifyListeners();

    await Future.delayed(stepDelay);
    if (_solverShouldStop) return true;

    await updateEdge(frame.r, frame.i, frame.e, -4);
    return true;
  }

  /// 사용자 click 과 동일한 경로(updateEdge) 로 솔버 수를 두고, 적용 후 보드가
  /// 일관 상태인지 deep propagation 으로 재검증한다. _applyConstraints 의
  /// guard 가 cascade-disable 모순을 조용히 revert 했을 때 솔버 입장에선
  /// state 가 "직접 OK" 로 보이는 함정을 막는다 — false 가 반환되면 호출자는
  /// 즉시 backtrack 해야 한다.
  Future<bool> _solverApplyAndCheck(int r, int i, int e, int value) async {
    await updateEdge(r, i, e, value);
    if (_solverShouldStop) return true;
    return !_detectDeepContradiction();
  }

  /// 현재 board state 에서 _propagateHypothesis 를 한 번 굴려 모순이 도출되는지
  /// 본다. propagation 은 edge 들을 변경하므로 snapshot/restore 로 감싼다.
  bool _detectDeepContradiction() {
    final snap = _snapshotEdges();
    final contra = _propagateHypothesis();
    _restoreEdges(snap);
    return contra;
  }

  /// undecided edge 마다 "이 edge 가 -1 이라고 가정하면 모순?" 을 검사.
  /// 모순이면 해당 edge 는 반드시 +1 이어야 한다.
  List<int>? _findForcedDrawByContradiction() {
    final Set<int> tested = {};
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < triPerRow; i++) {
        for (int e = 0; e < 3; e++) {
          if (_getEdge(r, i, e) != 0) continue;
          final canonical = _canonicalEdgeId(r, i, e);
          if (!tested.add(canonical)) continue;

          final snap = _snapshotEdges();
          _setEdgeValue(r, i, e, -1);
          final m = _sharedEdge(r, i, e);
          if (m != null) _setEdgeValue(m[0], m[1], m[2], -1);
          final contra = _propagateHypothesis();
          _restoreEdges(snap);

          if (contra) return [r, i, e];
        }
      }
    }
    return null;
  }

  /// undecided edge 마다 "이 edge 가 +1 이라고 가정하면 모순?" 을 검사.
  /// 모순이면 해당 edge 는 반드시 -1 (X) 이어야 한다. 기존 _runLookAhead 가
  /// _applyConstraints 안에서 동일 역할을 하지만 5 iter 제한이 있어 깊은
  /// 체인을 놓칠 수 있어 solver 루프에서 한 번 더 짚는다.
  List<int>? _findForcedDisableByContradiction() {
    final Set<int> tested = {};
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < triPerRow; i++) {
        for (int e = 0; e < 3; e++) {
          if (_getEdge(r, i, e) != 0) continue;
          final canonical = _canonicalEdgeId(r, i, e);
          if (!tested.add(canonical)) continue;

          final snap = _snapshotEdges();
          _setEdgeValue(r, i, e, 1);
          final m = _sharedEdge(r, i, e);
          if (m != null) _setEdgeValue(m[0], m[1], m[2], 1);
          final contra = _propagateHypothesis();
          _restoreEdges(snap);

          if (contra) return [r, i, e];
        }
      }
    }
    return null;
  }

  /// +1 가설 propagation 으로 변화량이 가장 큰 undecided edge 를 반환.
  /// contradiction 이 발생하는 edge 는 "확정 -1" 이므로 추측 후보에서 제외 —
  /// docs/auto_solver_bug_analysis.md §1 의 contradiction-as-guess 트랩 방지.
  List<int>? _pickHighestImpactGuess() {
    int bestScore = -1;
    List<int>? best;
    final Set<int> tested = {};
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < triPerRow; i++) {
        for (int e = 0; e < 3; e++) {
          if (_getEdge(r, i, e) != 0) continue;
          final canonical = _canonicalEdgeId(r, i, e);
          if (!tested.add(canonical)) continue;

          final snap = _snapshotEdges();
          _setEdgeValue(r, i, e, 1);
          final m = _sharedEdge(r, i, e);
          if (m != null) _setEdgeValue(m[0], m[1], m[2], 1);
          final contra = _propagateHypothesis();

          int changes = 0;
          if (!contra) {
            for (int rr = 0; rr < rows; rr++) {
              for (int ii = 0; ii < triPerRow; ii++) {
                for (int ee = 0; ee < 3; ee++) {
                  if (_getEdge(rr, ii, ee) != snap[rr][ii][ee]) changes++;
                }
              }
            }
          }
          _restoreEdges(snap);

          if (contra) continue;
          if (changes > bestScore) {
            bestScore = changes;
            best = [r, i, e];
          }
        }
      }
    }
    return best;
  }

  List<List<List<int>>> _snapshotEdges() {
    return List.generate(
        rows,
        (rr) => List.generate(triPerRow, (ii) => [
              puzzle[rr][ii].edge0,
              puzzle[rr][ii].edge1,
              puzzle[rr][ii].edge2,
            ]));
  }

  void _restoreEdges(List<List<List<int>>> snap) {
    for (int rr = 0; rr < rows; rr++) {
      for (int ii = 0; ii < triPerRow; ii++) {
        _setEdgeValue(rr, ii, 0, snap[rr][ii][0]);
        _setEdgeValue(rr, ii, 1, snap[rr][ii][1]);
        _setEdgeValue(rr, ii, 2, snap[rr][ii][2]);
      }
    }
  }
}

class _TriangleGuessFrame {
  final List<List<int>> snapshot;
  final int r;
  final int i;
  final int e;
  _TriangleGuessFrame(this.snapshot, this.r, this.i, this.e);
}
