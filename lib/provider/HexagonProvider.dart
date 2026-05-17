// ignore_for_file: file_names
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

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

  /// Difficulty for hint masking ("easy" 0.80, "normal" 0.55, "hard" 0.35).
  String difficulty = "normal";

  /// Canvas position (inside InteractiveViewer's child, including the
  /// scene's outer Padding(20)) of the most recently placed hint, or null
  /// if no hint is currently active. Used by the scene to pan the
  /// InteractiveViewer to the freshly-flashed edge.
  Offset? _hintCanvasPos;
  Offset? getHintCanvasPos() => _hintCanvasPos;

  /// Canvas centre of hex (r, c). Mirrors the layout in `_buildPuzzle`:
  /// each `HexagonBox` is W=R·√3 wide, 2R tall; rows overlap by R/2; odd
  /// rows are shifted right by W/2; the scene wraps the Column in
  /// Padding(20).
  Offset _hexCenter(int r, int c) {
    const double R = HexagonBoxState.cellSize;
    final double w = R * 1.7320508;
    const double scenePadding = 20.0;
    final double offsetX = (r & 1) == 1 ? w / 2 : 0;
    return Offset(
      scenePadding + offsetX + c * w + w / 2,
      scenePadding + R + r * 1.5 * R,
    );
  }

  /// Edge `e` midpoint relative to a pointy-top hex centre. e=0 top-right
  /// slanted, then clockwise.
  Offset _hexEdgeOffset(int e) {
    const double R = HexagonBoxState.cellSize;
    final double w = R * 1.7320508;
    switch (e) {
      case 0: return Offset(w / 4, -3 * R / 4);
      case 1: return Offset(w / 2, 0);
      case 2: return Offset(w / 4, 3 * R / 4);
      case 3: return Offset(-w / 4, 3 * R / 4);
      case 4: return Offset(-w / 2, 0);
      case 5: return Offset(-w / 4, -3 * R / 4);
    }
    return Offset.zero;
  }

  void setAnswer(List<List<int>> answer) {
    this.answer = answer;
    rows = answer.length;
    cols = answer[0].length ~/ 6;
  }

  void setSubmit(List<List<int>> submit) {
    this.submit = submit;
  }

  void setDifficulty(String d) {
    difficulty = d;
  }

  Future<void> init() async {
    _buildPuzzle();
    _applyConstraints();
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

    // Build widget tree with pointy-top hex grid layout.
    // Widget box: W = R·√3, H = 2R. Same-row hexagons abut (no gap).
    // Odd rows shifted right by W/2; vertical centre spacing = 3R/2 so
    // rows overlap by R/2 upward per row (handled with Transform.translate).
    //
    // Each row is wrapped in a SizedBox of width (cols + 0.5)·W so the
    // Column's bounding rect covers the full extent of *odd* rows too —
    // otherwise the rightmost odd-row hexagons are painted via Transform
    // but lie outside the Column's hit-test bounds, making their right
    // edges untappable.
    final double hexR = HexagonBoxState.cellSize;
    final double hexW = hexR * 1.732; // R·√3
    final double rowOverlapY = hexR / 2;
    final double rowLayoutWidth = (cols + 0.5) * hexW;

    for (int r = 0; r < rows; r++) {
      bool isOddRow = r % 2 == 1;

      List<Widget> rowChildren = [];
      for (int c = 0; c < cols; c++) {
        rowChildren.add(puzzle[r][c]);
      }

      hexagonField.add(Transform.translate(
        offset: Offset(0, -r * rowOverlapY),
        child: SizedBox(
          width: rowLayoutWidth,
          child: Padding(
            padding: EdgeInsets.only(left: isOddRow ? hexW / 2 : 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: rowChildren,
            ),
          ),
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
    _maskByDifficulty();
  }

  /// Hide a deterministic subset of clue cells so the same puzzle + difficulty
  /// always reveals the same set on each load. Seeded by the answer hash so
  /// Continue mode reproduces the original mask without needing to persist it.
  void _maskByDifficulty() {
    double ratio;
    switch (difficulty) {
      case "easy": ratio = 0.80; break;
      case "hard": ratio = 0.35; break;
      default: ratio = 0.55;
    }
    if (ratio >= 1.0) return;

    int seed = 0;
    for (final row in answer) {
      for (final v in row) {
        seed = (seed * 31 + v) & 0x7FFFFFFF;
      }
    }
    final List<List<int>> cells = [];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        cells.add([r, c]);
      }
    }
    cells.shuffle(Random(seed));
    final int keep = (cells.length * ratio).round();
    for (int i = keep; i < cells.length; i++) {
      puzzle[cells[i][0]][cells[i][1]].num = -1;
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

  /// Neighbour deltas per edge index (0..5) for pointy-top row-offset tiling
  /// where odd rows are shifted right. Edge i of (r,c) is shared with the
  /// neighbour at (r+dr, c+dc) on that neighbour's edge (i+3)%6.
  static const List<List<int>> _nbEven = [
    [-1, 0],  // 0 top-right slanted  -> NE
    [0, 1],   // 1 right vertical      -> E
    [1, 0],   // 2 bottom-right slanted-> SE
    [1, -1],  // 3 bottom-left slanted -> SW
    [0, -1],  // 4 left vertical       -> W
    [-1, -1], // 5 top-left slanted    -> NW
  ];
  static const List<List<int>> _nbOdd = [
    [-1, 1], [0, 1], [1, 1], [1, 0], [0, -1], [-1, 0],
  ];

  /// Returns (neighbourRow, neighbourCol, neighbourEdgeIdx) for the shared
  /// edge, or null if the neighbour would fall outside the grid.
  List<int>? _neighborEdge(int row, int col, int edgeIdx) {
    final delta = (row & 1) == 0 ? _nbEven[edgeIdx] : _nbOdd[edgeIdx];
    final nr = row + delta[0];
    final nc = col + delta[1];
    if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) return null;
    return [nr, nc, (edgeIdx + 3) % 6];
  }

  /// Called when user taps an edge
  Future<void> updateEdge(int row, int col, int edgeIdx, int value) async {
    _undoStack.add(submit.map((r) => List<int>.from(r)).toList());
    _redoStack.clear();

    // Color merging: if the user drew a positive edge, prefer an adjacent
    // chain's color over the random one passed in. If multiple chains meet
    // at this edge, recolor the others into the chosen color so the whole
    // connected component shares one colour. Matches SquareProvider.
    int finalValue = value;
    if (value >= 1) {
      final List<List<int>> adj = _adjacentEdges(row, col, edgeIdx);
      final Set<int> nearColors = {};
      for (final a in adj) {
        final v = puzzle[a[0]][a[1]].edges[a[2]];
        if (v >= 1) nearColors.add(v);
      }
      if (nearColors.isNotEmpty) {
        finalValue = nearColors.first;
        for (final a in adj) {
          final v = puzzle[a[0]][a[1]].edges[a[2]];
          if (v >= 1 && v != finalValue) {
            _recolorChain(a[0], a[1], a[2], finalValue);
          }
        }
      }
    }

    puzzle[row][col].edges[edgeIdx] = finalValue;
    final nb = _neighborEdge(row, col, edgeIdx);
    if (nb != null) {
      puzzle[nb[0]][nb[1]].edges[nb[2]] = finalValue;
    }
    _applyConstraints();
    submit = _readSubmit();
    notifyListeners();

    _checkComplete();
  }

  /// Canonical integer ID for a (potentially shared) edge — lex-min of self
  /// and its neighbour's mirror, so both sides resolve to the same ID.
  int _canonicalEdgeId(int r, int c, int e) {
    final selfId = (r * 1000 + c) * 10 + e;
    final nb = _neighborEdge(r, c, e);
    if (nb == null) return selfId;
    final otherId = (nb[0] * 1000 + nb[1]) * 10 + nb[2];
    return selfId <= otherId ? selfId : otherId;
  }

  /// In-grid edges incident to vertex (vx, vy), as [r, c, e] tuples (one
  /// per unique edge — shared edges are deduplicated by canonical ID).
  List<List<int>> _edgesAtVertex(int vx, int vy) {
    final List<List<int>> out = [];
    final Set<int> seen = {};
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        for (int vi = 0; vi < 6; vi++) {
          final coord = _vertexCoord(r, c, vi);
          if (coord[0] != vx || coord[1] != vy) continue;
          for (final e in [vi, (vi + 5) % 6]) {
            final id = _canonicalEdgeId(r, c, e);
            if (seen.add(id)) out.add([r, c, e]);
          }
        }
      }
    }
    return out;
  }

  /// All edges sharing a vertex with edge (r, c, e), excluding the edge itself.
  List<List<int>> _adjacentEdges(int r, int c, int e) {
    final v0 = _vertexCoord(r, c, e);
    final v1 = _vertexCoord(r, c, (e + 1) % 6);
    final selfId = _canonicalEdgeId(r, c, e);
    final List<List<int>> out = [];
    final Set<int> seen = {selfId};
    for (final v in [v0, v1]) {
      for (final adj in _edgesAtVertex(v[0], v[1])) {
        final id = _canonicalEdgeId(adj[0], adj[1], adj[2]);
        if (seen.add(id)) out.add(adj);
      }
    }
    return out;
  }

  /// BFS from (r, c, e), recoloring every drawn edge reachable through the
  /// current colour into [newValue]. Walks adjacency at vertices.
  void _recolorChain(int r, int c, int e, int newValue) {
    final int oldValue = puzzle[r][c].edges[e];
    if (oldValue == newValue || oldValue < 1) return;
    final List<List<int>> queue = [[r, c, e]];
    final Set<int> visited = {_canonicalEdgeId(r, c, e)};
    int idx = 0;
    while (idx < queue.length) {
      final cur = queue[idx++];
      final cr = cur[0], cc = cur[1], ce = cur[2];
      if (puzzle[cr][cc].edges[ce] != oldValue) continue;
      puzzle[cr][cc].edges[ce] = newValue;
      final nbe = _neighborEdge(cr, cc, ce);
      if (nbe != null) puzzle[nbe[0]][nbe[1]].edges[nbe[2]] = newValue;
      for (final adj in _adjacentEdges(cr, cc, ce)) {
        if (puzzle[adj[0]][adj[1]].edges[adj[2]] == oldValue) {
          final id = _canonicalEdgeId(adj[0], adj[1], adj[2]);
          if (visited.add(id)) queue.add(adj);
        }
      }
    }
  }

  /// Constraint propagation entry point. Wipes prior auto-disables (-1) and
  /// also user "disagreement" reds (-2) so that look-ahead doesn't lock -2
  /// as a hard premise (which would create spurious cascade -1's on edges
  /// that a freshly-derived state wouldn't disable). After propagation,
  /// -2 is restored at positions whose new value is -1 — the user's red
  /// marking refers to "this -1", so it only stays where -1 still holds.
  /// User X marks (-4) are hard locks and are not touched.
  ///
  /// Global-infeasibility guard: if the user X-marks a drawn line that was
  /// critical for some clue, the puzzle becomes globally infeasible.
  /// Look-ahead would then mark every undecided edge as -1 (every hypothesis
  /// contradicts) and wipe the board. We snapshot the full edges grid at
  /// entry; if the post-propagation state is locally inconsistent (caught
  /// by _isStateConsistent), we restore from snapshot — the user's tap is
  /// preserved, no cascade is applied. See docs §4 / §5.
  void _applyConstraints() {
    final List<List<List<int>>> guardSnap = List.generate(rows, (rr) =>
        List.generate(cols, (cc) => List<int>.from(puzzle[rr][cc].edges)));

    final List<List<int>> redSnapshot = [];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        for (int e = 0; e < 6; e++) {
          final v = puzzle[r][c].edges[e];
          if (v == -1) {
            puzzle[r][c].edges[e] = 0;
          } else if (v == -2) {
            redSnapshot.add([r, c, e]);
            puzzle[r][c].edges[e] = 0;
          }
        }
      }
    }

    // Capture consistency AFTER clearing so it reflects what propagation sees.
    // Only revert when propagation TURNED a previously-OK state into an
    // inconsistent one. If the user over-drew a clue cell, direct-rule
    // cascade is local and provides useful "you can't draw here" feedback —
    // we keep those results.
    final bool entryConsistent = _isStateConsistent();

    _propagateDirect();
    for (int laIter = 0; laIter < 5; laIter++) {
      if (!_runLookAhead()) break;
      _propagateDirect();
    }

    for (final pos in redSnapshot) {
      if (puzzle[pos[0]][pos[1]].edges[pos[2]] == -1) {
        puzzle[pos[0]][pos[1]].edges[pos[2]] = -2;
        final nb = _neighborEdge(pos[0], pos[1], pos[2]);
        if (nb != null && puzzle[nb[0]][nb[1]].edges[nb[2]] == -1) {
          puzzle[nb[0]][nb[1]].edges[nb[2]] = -2;
        }
      }
    }

    if (entryConsistent && !_isStateConsistent()) {
      for (int rr = 0; rr < rows; rr++) {
        for (int cc = 0; cc < cols; cc++) {
          for (int ee = 0; ee < 6; ee++) {
            puzzle[rr][cc].edges[ee] = guardSnap[rr][cc][ee];
          }
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

  /// Cell rule: when a clue cell has `num` selected edges (value ≥ 1), any
  /// remaining undecided edges (value == 0) are auto-disabled (-1). Shared
  /// edges are synchronised to the neighbour cell. Clues with num < 0 are
  /// skipped (hidden hint).
  bool _runCellRule() {
    bool anyChange = false;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final int num = puzzle[r][c].num;
        if (num < 0) continue;
        int active = 0;
        for (int e = 0; e < 6; e++) {
          if (puzzle[r][c].edges[e] >= 1) active++;
        }
        if (active < num) continue;
        for (int e = 0; e < 6; e++) {
          if (puzzle[r][c].edges[e] == 0) {
            puzzle[r][c].edges[e] = -1;
            final nb = _neighborEdge(r, c, e);
            if (nb != null) {
              puzzle[nb[0]][nb[1]].edges[nb[2]] = -1;
            }
            anyChange = true;
          }
        }
      }
    }
    return anyChange;
  }

  /// Builds the vertex-incidence map: for every grid vertex, the list of
  /// unique [r, c, e, canonicalId] tuples for edges meeting at it. Shared
  /// edges are deduplicated by canonical lex-min ID.
  Map<int, List<List<int>>> _buildVertexIncidence() {
    final Map<int, List<List<int>>> incident = {};
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        for (int vi = 0; vi < 6; vi++) {
          final coord = _vertexCoord(r, c, vi);
          final key = coord[0] * 100000 + coord[1];
          // The two edges of hex (r,c) incident to v[vi] are edge vi and edge (vi+5)%6.
          for (final e in [vi, (vi + 5) % 6]) {
            final list = incident.putIfAbsent(key, () => []);
            final nb = _neighborEdge(r, c, e);
            int selfId = (r * 1000 + c) * 10 + e;
            int otherId = nb == null ? -1 : (nb[0] * 1000 + nb[1]) * 10 + nb[2];
            int canonical = (otherId == -1 || selfId <= otherId) ? selfId : otherId;
            bool dup = false;
            for (final existing in list) {
              if (existing[3] == canonical) { dup = true; break; }
            }
            if (!dup) list.add([r, c, e, canonical]);
          }
        }
      }
    }
    return incident;
  }

  /// Vertex-degree rule: a Slitherlink vertex must end at degree 0 or 2.
  /// If two edges at a vertex are already drawn, remaining undecided edges
  /// become -1. If active + undecided < 2, the loop can't reach degree 2 here,
  /// so any remaining undecided edges also become -1.
  ///
  /// Vertex coords use integer (vx, vy) with unit = (W/2, R/2), letting the
  /// six vertices of every hex resolve to small integer pairs without any
  /// floating-point keying.
  bool _runVertexRule() {
    final incident = _buildVertexIncidence();

    bool anyChange = false;
    for (final edges in incident.values) {
      int active = 0, undecided = 0;
      for (final e in edges) {
        final v = puzzle[e[0]][e[1]].edges[e[2]];
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
        if (puzzle[e[0]][e[1]].edges[e[2]] == 0) {
          puzzle[e[0]][e[1]].edges[e[2]] = -1;
          final nb = _neighborEdge(e[0], e[1], e[2]);
          if (nb != null) {
            puzzle[nb[0]][nb[1]].edges[nb[2]] = -1;
          }
          anyChange = true;
        }
      }
    }
    return anyChange;
  }

  /// Returns true iff the live puzzle state already violates a hard
  /// constraint (clue over-fill, clue under-fill with no remaining slack,
  /// vertex over-degree, or vertex stuck at degree 1). Look-ahead would
  /// otherwise treat every hypothesis as contradicting and disable every
  /// undecided edge, so we bail in that case.
  bool _isStateConsistent() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final num = puzzle[r][c].num;
        if (num < 0) continue;
        int active = 0, undecided = 0;
        for (int e = 0; e < 6; e++) {
          final v = puzzle[r][c].edges[e];
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
    final incident = _buildVertexIncidence();
    for (final edges in incident.values) {
      int active = 0, undecided = 0;
      for (final e in edges) {
        final v = puzzle[e[0]][e[1]].edges[e[2]];
        if (v >= 1) {
          active++;
        } else if (v == 0) {
          undecided++;
        }
      }
      if (active > 2) return false;
      if (active == 1 && undecided == 0) return false;
    }
    return true;
  }

  /// Look-ahead pass. For each undecided edge: snapshot the grid, hypothesise
  /// the edge as drawn (=1), run a hypothetical propagator that includes
  /// force-draw rules and contradiction detection, then restore. If the
  /// hypothesis broke a clue or vertex, the actual edge is flagged -1.
  ///
  /// Hypothetical propagation is internal — it never persists to the live
  /// puzzle. Only the final -1 assignment on a contradicted edge is permanent.
  bool _runLookAhead() {
    if (!_isStateConsistent()) return false;
    bool anyChange = false;
    final Set<int> tested = {};
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        for (int e = 0; e < 6; e++) {
          if (puzzle[r][c].edges[e] != 0) continue;
          final canonical = _canonicalEdgeId(r, c, e);
          if (!tested.add(canonical)) continue;

          final snap = List.generate(rows, (rr) =>
              List.generate(cols, (cc) => List<int>.from(puzzle[rr][cc].edges)));

          puzzle[r][c].edges[e] = 1;
          final nb = _neighborEdge(r, c, e);
          if (nb != null) puzzle[nb[0]][nb[1]].edges[nb[2]] = 1;

          final contradiction = _propagateHypothesis();

          for (int rr = 0; rr < rows; rr++) {
            for (int cc = 0; cc < cols; cc++) {
              for (int ee = 0; ee < 6; ee++) {
                puzzle[rr][cc].edges[ee] = snap[rr][cc][ee];
              }
            }
          }

          if (contradiction) {
            puzzle[r][c].edges[e] = -1;
            if (nb != null) puzzle[nb[0]][nb[1]].edges[nb[2]] = -1;
            anyChange = true;
          }
        }
      }
    }
    return anyChange;
  }

  /// Hypothetical propagator used inside _runLookAhead. Mutates puzzle.edges
  /// freely — caller must snapshot+restore. Returns true on contradiction.
  ///
  /// Adds to the live rules (cell-disable / vertex-disable):
  ///   • Cell force-draw: if active + undecided == num, the undecided edges
  ///     must be drawn.
  ///   • Vertex force-draw: if active == 1 and exactly one edge is undecided,
  ///     it must be drawn (degree must reach 2).
  ///   • Contradictions: cell active > num, cell active + undecided < num,
  ///     vertex active > 2, vertex active == 1 with no undecided.
  bool _propagateHypothesis() {
    final incident = _buildVertexIncidence();

    for (int iter = 0; iter < 30; iter++) {
      bool changed = false;

      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          final num = puzzle[r][c].num;
          if (num < 0) continue;
          int active = 0, undecided = 0;
          for (int e = 0; e < 6; e++) {
            final v = puzzle[r][c].edges[e];
            if (v >= 1) {
              active++;
            } else if (v == 0) {
              undecided++;
            }
          }
          if (active > num) return true;
          if (active + undecided < num) return true;
          if (active == num && undecided > 0) {
            for (int e = 0; e < 6; e++) {
              if (puzzle[r][c].edges[e] == 0) {
                puzzle[r][c].edges[e] = -1;
                final nb = _neighborEdge(r, c, e);
                if (nb != null) puzzle[nb[0]][nb[1]].edges[nb[2]] = -1;
                changed = true;
              }
            }
          } else if (active + undecided == num && undecided > 0) {
            for (int e = 0; e < 6; e++) {
              if (puzzle[r][c].edges[e] == 0) {
                puzzle[r][c].edges[e] = 1;
                final nb = _neighborEdge(r, c, e);
                if (nb != null) puzzle[nb[0]][nb[1]].edges[nb[2]] = 1;
                changed = true;
              }
            }
          }
        }
      }

      for (final edges in incident.values) {
        int active = 0, undecided = 0;
        for (final e in edges) {
          final v = puzzle[e[0]][e[1]].edges[e[2]];
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
            if (puzzle[e[0]][e[1]].edges[e[2]] == 0) {
              puzzle[e[0]][e[1]].edges[e[2]] = -1;
              final nb = _neighborEdge(e[0], e[1], e[2]);
              if (nb != null) puzzle[nb[0]][nb[1]].edges[nb[2]] = -1;
              changed = true;
            }
          }
        } else if (active == 0 && undecided > 0 && undecided < 2) {
          for (final e in edges) {
            if (puzzle[e[0]][e[1]].edges[e[2]] == 0) {
              puzzle[e[0]][e[1]].edges[e[2]] = -1;
              final nb = _neighborEdge(e[0], e[1], e[2]);
              if (nb != null) puzzle[nb[0]][nb[1]].edges[nb[2]] = -1;
              changed = true;
            }
          }
        } else if (active == 1 && undecided == 1) {
          for (final e in edges) {
            if (puzzle[e[0]][e[1]].edges[e[2]] == 0) {
              puzzle[e[0]][e[1]].edges[e[2]] = 1;
              final nb = _neighborEdge(e[0], e[1], e[2]);
              if (nb != null) puzzle[nb[0]][nb[1]].edges[nb[2]] = 1;
              changed = true;
            }
          }
        }
      }

      if (!changed) break;
    }
    return false;
  }

  /// Integer vertex coordinate in (W/2, R/2) units. v[0]=top, v[1]=top-right,
  /// v[2]=bottom-right, v[3]=bottom, v[4]=bottom-left, v[5]=top-left.
  List<int> _vertexCoord(int r, int c, int vi) {
    final int cx = 2 * c + (r & 1);
    final int cy = 3 * r;
    switch (vi) {
      case 0: return [cx, cy - 2];
      case 1: return [cx + 1, cy - 1];
      case 2: return [cx + 1, cy + 1];
      case 3: return [cx, cy + 2];
      case 4: return [cx - 1, cy + 1];
      case 5: return [cx - 1, cy - 1];
    }
    return [cx, cy];
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
    _applyConstraints();
    submit = _readSubmit();
    notifyListeners();
  }

  Future<void> redo() async {
    if (_redoStack.isEmpty) return;
    _undoStack.add(submit.map((r) => List<int>.from(r)).toList());
    submit = _redoStack.removeLast();
    _applySubmit();
    _applyConstraints();
    submit = _readSubmit();
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
    submit = _readSubmit();
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
      for (int c = 0; c < cols; c++) {
        int base = c * 6;
        for (int e = 0; e < 6; e++) {
          if (answer[r][base + e] == 1 && submit[r][base + e] <= 0) {
            puzzle[r][c].edges[e] = -3;
            final nb = _neighborEdge(r, c, e);
            if (nb != null) {
              puzzle[nb[0]][nb[1]].edges[nb[2]] = -3;
            }
            _hintCanvasPos = _hexCenter(r, c) + _hexEdgeOffset(e);
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

  int getBoxColor(int row, int col) => 0;

  ///**********************************************************************************
  ///****************** human-like auto solver ******************
  ///**********************************************************************************
  /// Square / Triangle 솔버와 동일 골격. 한 수씩 forced-draw → forced-disable
  /// 순으로 확정을 그어주고, 확정이 없으면 영향력 최대 edge 로 추측. 추측이
  /// 실패하면 직전 추측 시점의 submit 스냅샷으로 복원하고 실패 edge 를
  /// 사용자 X (-4) 로 잠근다. 최대 3 단계 추측.
  static const int _solverMaxGuesses = 3;
  static const Duration _solverStepDelay = Duration(milliseconds: 500);

  bool _solverRunning = false;
  bool _solverShouldStop = false;
  String _solverStatus = "";

  bool get isSolverRunning => _solverRunning;
  String get solverStatus => _solverStatus;

  void cancelSolver() {
    _solverShouldStop = true;
  }

  Future<void> solveHumanLike() async {
    if (_solverRunning) return;
    _solverRunning = true;
    _solverShouldStop = false;
    _solverStatus = "solver_running";
    notifyListeners();

    final List<_HexagonGuessFrame> guesses = [];

    try {
      while (!_solverShouldStop) {
        submit = _readSubmit();
        if (_isPuzzleSolvedLocal()) {
          _solverStatus = "solver_done";
          notifyListeners();
          break;
        }

        if (!_isStateConsistent()) {
          if (!await _backtrackToLastGuess(guesses)) break;
          await Future.delayed(_solverStepDelay);
          continue;
        }

        final List<int>? draw = _findForcedDrawByContradiction();
        if (draw != null) {
          _solverStatus = "solver_step";
          notifyListeners();
          final ok = await _solverApplyAndCheck(
              draw[0], draw[1], draw[2], themeColor.getNormalRandom());
          if (_solverShouldStop) break;
          if (!ok) {
            if (!await _backtrackToLastGuess(guesses)) break;
          }
          await Future.delayed(_solverStepDelay);
          continue;
        }

        final List<int>? disable = _findForcedDisableByContradiction();
        if (disable != null) {
          _solverStatus = "solver_step";
          notifyListeners();
          final ok = await _solverApplyAndCheck(
              disable[0], disable[1], disable[2], -4);
          if (_solverShouldStop) break;
          if (!ok) {
            if (!await _backtrackToLastGuess(guesses)) break;
          }
          await Future.delayed(_solverStepDelay);
          continue;
        }

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
        guesses.add(_HexagonGuessFrame(snap, guess[0], guess[1], guess[2]));
        _solverStatus = "solver_guess";
        notifyListeners();
        final ok = await _solverApplyAndCheck(
            guess[0], guess[1], guess[2], themeColor.getNormalRandom());
        if (_solverShouldStop) break;
        if (!ok) {
          if (!await _backtrackToLastGuess(guesses)) break;
        }
        await Future.delayed(_solverStepDelay);
      }
    } finally {
      _solverRunning = false;
      notifyListeners();
    }
  }

  bool _isPuzzleSolvedLocal() {
    if (rows == 0 || answer.isEmpty) return false;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final int base = c * 6;
        for (int e = 0; e < 6; e++) {
          final bool ansSel = answer[r][base + e] == 1;
          final bool subSel = puzzle[r][c].edges[e] >= 1;
          if (ansSel != subSel) return false;
        }
      }
    }
    return true;
  }

  Future<bool> _backtrackToLastGuess(
      List<_HexagonGuessFrame> guesses) async {
    if (guesses.isEmpty) {
      _solverStatus = "solver_stuck";
      notifyListeners();
      return false;
    }
    final frame = guesses.removeLast();
    _solverStatus = "solver_backtrack";
    notifyListeners();

    _undoStack.add(submit.map((r) => List<int>.from(r)).toList());
    _redoStack.clear();
    submit = frame.snapshot.map((r) => List<int>.from(r)).toList();
    _applySubmit();
    _applyConstraints();
    submit = _readSubmit();
    notifyListeners();

    await Future.delayed(_solverStepDelay);
    if (_solverShouldStop) return true;

    await updateEdge(frame.r, frame.c, frame.e, -4);
    return true;
  }

  Future<bool> _solverApplyAndCheck(int r, int c, int e, int value) async {
    await updateEdge(r, c, e, value);
    if (_solverShouldStop) return true;
    return !_detectDeepContradiction();
  }

  bool _detectDeepContradiction() {
    final snap = _snapshotEdges();
    final contra = _propagateHypothesis();
    _restoreEdges(snap);
    return contra;
  }

  /// undecided edge 마다 "이 edge 가 -1 이라고 가정하면 모순?" 검사 → 확정 +1.
  List<int>? _findForcedDrawByContradiction() {
    final Set<int> tested = {};
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        for (int e = 0; e < 6; e++) {
          if (puzzle[r][c].edges[e] != 0) continue;
          final canonical = _canonicalEdgeId(r, c, e);
          if (!tested.add(canonical)) continue;

          final snap = _snapshotEdges();
          puzzle[r][c].edges[e] = -1;
          final nb = _neighborEdge(r, c, e);
          if (nb != null) puzzle[nb[0]][nb[1]].edges[nb[2]] = -1;
          final contra = _propagateHypothesis();
          _restoreEdges(snap);

          if (contra) return [r, c, e];
        }
      }
    }
    return null;
  }

  /// undecided edge 마다 "이 edge 가 +1 이라고 가정하면 모순?" 검사 → 확정 -1.
  /// _runLookAhead 가 이미 _applyConstraints 안에서 잡지만 5 iter 제한이
  /// 있어 깊은 체인 -1 확정을 놓칠 수 있어 solver 가 한 번 더 짚는다.
  List<int>? _findForcedDisableByContradiction() {
    final Set<int> tested = {};
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        for (int e = 0; e < 6; e++) {
          if (puzzle[r][c].edges[e] != 0) continue;
          final canonical = _canonicalEdgeId(r, c, e);
          if (!tested.add(canonical)) continue;

          final snap = _snapshotEdges();
          puzzle[r][c].edges[e] = 1;
          final nb = _neighborEdge(r, c, e);
          if (nb != null) puzzle[nb[0]][nb[1]].edges[nb[2]] = 1;
          final contra = _propagateHypothesis();
          _restoreEdges(snap);

          if (contra) return [r, c, e];
        }
      }
    }
    return null;
  }

  /// +1 가설 propagation 으로 변화량이 가장 큰 undecided edge 반환.
  /// contradiction 인 edge 는 "확정 -1" 이므로 추측 후보에서 제외 —
  /// docs/auto_solver_bug_analysis.md §1 의 contradiction-as-guess 트랩 방지.
  List<int>? _pickHighestImpactGuess() {
    int bestScore = -1;
    List<int>? best;
    final Set<int> tested = {};
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        for (int e = 0; e < 6; e++) {
          if (puzzle[r][c].edges[e] != 0) continue;
          final canonical = _canonicalEdgeId(r, c, e);
          if (!tested.add(canonical)) continue;

          final snap = _snapshotEdges();
          puzzle[r][c].edges[e] = 1;
          final nb = _neighborEdge(r, c, e);
          if (nb != null) puzzle[nb[0]][nb[1]].edges[nb[2]] = 1;
          final contra = _propagateHypothesis();

          int changes = 0;
          if (!contra) {
            for (int rr = 0; rr < rows; rr++) {
              for (int cc = 0; cc < cols; cc++) {
                for (int ee = 0; ee < 6; ee++) {
                  if (puzzle[rr][cc].edges[ee] != snap[rr][cc][ee]) {
                    changes++;
                  }
                }
              }
            }
          }
          _restoreEdges(snap);

          if (contra) continue;
          if (changes > bestScore) {
            bestScore = changes;
            best = [r, c, e];
          }
        }
      }
    }
    return best;
  }

  List<List<List<int>>> _snapshotEdges() {
    return List.generate(
        rows,
        (rr) => List.generate(
            cols, (cc) => List<int>.from(puzzle[rr][cc].edges)));
  }

  void _restoreEdges(List<List<List<int>>> snap) {
    for (int rr = 0; rr < rows; rr++) {
      for (int cc = 0; cc < cols; cc++) {
        for (int ee = 0; ee < 6; ee++) {
          puzzle[rr][cc].edges[ee] = snap[rr][cc][ee];
        }
      }
    }
  }
}

class _HexagonGuessFrame {
  final List<List<int>> snapshot;
  final int r;
  final int c;
  final int e;
  _HexagonGuessFrame(this.snapshot, this.r, this.c, this.e);
}
