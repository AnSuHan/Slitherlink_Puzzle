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
    // Odd rows shifted right by W/2 via Transform (not SizedBox — keeping
    // both rows the same layout width so Column centring puts them on the
    // same baseline, then Transform nudges odd rows horizontally). Vertical
    // centre spacing = 3R/2, so rows overlap by R/2 upward per row.
    final double hexR = HexagonBoxState.cellSize;
    final double hexW = hexR * 1.732; // R·√3
    final double rowOverlapY = hexR / 2;

    for (int r = 0; r < rows; r++) {
      bool isOddRow = r % 2 == 1;

      List<Widget> rowChildren = [];
      for (int c = 0; c < cols; c++) {
        rowChildren.add(puzzle[r][c]);
      }

      hexagonField.add(Transform.translate(
        offset: Offset(isOddRow ? hexW / 2 : 0, -r * rowOverlapY),
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
  /// then iterates the cell rule and vertex-degree rule until a fixed point.
  /// User annotations (-2 wrong, -4 X) are preserved throughout.
  void _applyConstraints() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        for (int e = 0; e < 6; e++) {
          if (puzzle[r][c].edges[e] == -1) {
            puzzle[r][c].edges[e] = 0;
          }
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

  /// Vertex-degree rule: a Slitherlink vertex must end at degree 0 or 2.
  /// If two edges at a vertex are already drawn, remaining undecided edges
  /// become -1. If active + undecided < 2, the loop can't reach degree 2 here,
  /// so any remaining undecided edges also become -1.
  ///
  /// Vertex coords use integer (vx, vy) with unit = (W/2, R/2), letting the
  /// six vertices of every hex resolve to small integer pairs without any
  /// floating-point keying.
  bool _runVertexRule() {
    final Map<int, List<List<int>>> incident = {};
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        for (int vi = 0; vi < 6; vi++) {
          final coord = _vertexCoord(r, c, vi);
          final key = coord[0] * 100000 + coord[1];
          // The two edges of hex (r,c) incident to v[vi] are edge vi and edge (vi+5)%6.
          for (final e in [vi, (vi + 5) % 6]) {
            final list = incident.putIfAbsent(key, () => []);
            // Dedup shared edges by canonical (lex-min of self and neighbour).
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
}
