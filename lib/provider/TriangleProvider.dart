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
    // 갓 로드된 보드는 단서만 보여준다. _applyConstraints 의 look-ahead 추론까지
    // 돌리면 풀 수 없는 대량의 edge 가 즉시 -1 로 칠해지며 정답 라인이 첫
    // 화면에 드러난다(스포일러). 자명한 직접규칙(_propagateDirect)만 적용하고,
    // 깊은 추론은 사용자 첫 수에 updateEdge → _applyConstraints 에서 나타난다.
    _propagateDirect();
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

    // Color merging: if a positive (drawn) edge is added, prefer an adjacent
    // chain's color over the random one passed in. If multiple chains meet at
    // this edge's vertices, recolor the others into the chosen color so the
    // whole connected component shares one colour. Matches Hexagon/Trihex/Square.
    int finalValue = value;
    if (value >= 1) {
      final List<List<int>> adj = _adjacentEdges(row, idx, edgeIdx);
      final Set<int> nearColors = {};
      for (final a in adj) {
        final v = _getEdge(a[0], a[1], a[2]);
        if (v >= 1) nearColors.add(v);
      }
      if (nearColors.isNotEmpty) {
        finalValue = nearColors.first;
        for (final a in adj) {
          final v = _getEdge(a[0], a[1], a[2]);
          if (v >= 1 && v != finalValue) {
            _recolorChain(a[0], a[1], a[2], finalValue);
          }
        }
      }
    }

    _setEdgeValue(row, idx, edgeIdx, finalValue);
    final mirror = _sharedEdge(row, idx, edgeIdx);
    if (mirror != null) {
      _setEdgeValue(mirror[0], mirror[1], mirror[2], finalValue);
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

    // Direct rule 결과는 단조적·건전한 deduction 이므로 보존한다.
    // 이후 look-ahead 가 hidden-clue 환경에서 잘못 발화해 모순을 만들면
    // revert 는 여기까지로만 되돌린다. entry (guardSnap) 까지 가면 0-clue
    // 셀 자동 -1 같은 확정 표시가 init 직후 사라진다.
    final List<List<List<int>>> afterDirect = List.generate(rows, (rr) =>
        List.generate(triPerRow, (ii) => [
              puzzle[rr][ii].edge0,
              puzzle[rr][ii].edge1,
              puzzle[rr][ii].edge2,
            ]));

    // 자동풀기 oracle 수에서는 look-ahead 를 건너뛴다 (per-edge 가설 →
    // O(edges) 비용). oracle 이 정답을 보장하므로 look-ahead 의 추가 -1 표시는
    // cosmetic 일 뿐이고, 이 패스가 삼각형 자동풀기 속도를 좌우했다. 사용자 탭/
    // backtrack/init 등 _solverFastApply 가 꺼진 경로에서는 그대로 동작한다.
    if (!_solverFastApply) {
      for (int laIter = 0; laIter < 5; laIter++) {
        if (!_runLookAhead()) break;
        _propagateDirect();
      }
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
      // Look-ahead 가 만든 모순만 되돌리고 direct 결과는 유지.
      for (int rr = 0; rr < rows; rr++) {
        for (int ii = 0; ii < triPerRow; ii++) {
          puzzle[rr][ii].edge0 = afterDirect[rr][ii][0];
          puzzle[rr][ii].edge1 = afterDirect[rr][ii][1];
          puzzle[rr][ii].edge2 = afterDirect[rr][ii][2];
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

  // --- Color chain adjacency (vertex-shared edges) ------------------------
  // Inverse of [_incidentEdges]: canonical edge id -> its (≤2) endpoint
  // vertices. Built once per board geometry; rebuilt if rows/triPerRow change
  // (restart / new game with a different size). Drives the color-merging in
  // [updateEdge] so a connected line shares one colour.
  Map<int, List<List<int>>>? _edgeVertCache;
  int _edgeVertCacheKey = -1;

  Map<int, List<List<int>>> _edgeVertices() {
    final int key = rows * 100000 + triPerRow;
    final cached = _edgeVertCache;
    if (cached != null && _edgeVertCacheKey == key) return cached;
    final Map<int, List<List<int>>> map = {};
    for (int vr = 0; vr <= rows; vr++) {
      for (int vi = 0; vi <= triPerRow + 1; vi++) {
        if ((vr + vi).isEven) continue; // only vr+vi odd are real vertices
        for (final e in _incidentEdges(vr, vi)) {
          final id = _canonicalEdgeId(e[0], e[1], e[2]);
          (map[id] ??= []).add([vr, vi]);
        }
      }
    }
    _edgeVertCache = map;
    _edgeVertCacheKey = key;
    return map;
  }

  /// All edges sharing a vertex with edge (r, i, e), excluding the edge itself.
  /// One representative [r, i, e] per unique (canonical) edge.
  List<List<int>> _adjacentEdges(int r, int i, int e) {
    final int selfId = _canonicalEdgeId(r, i, e);
    final verts = _edgeVertices()[selfId] ?? const [];
    final List<List<int>> out = [];
    final Set<int> seen = {selfId};
    for (final v in verts) {
      for (final adj in _incidentEdges(v[0], v[1])) {
        final id = _canonicalEdgeId(adj[0], adj[1], adj[2]);
        if (seen.add(id)) out.add(adj);
      }
    }
    return out;
  }

  /// BFS from (r, i, e), recoloring every drawn edge reachable through the
  /// current colour into [newValue]. Walks adjacency at shared vertices.
  void _recolorChain(int r, int i, int e, int newValue) {
    final int oldValue = _getEdge(r, i, e);
    if (oldValue == newValue || oldValue < 1) return;
    final List<List<int>> queue = [
      [r, i, e]
    ];
    final Set<int> visited = {_canonicalEdgeId(r, i, e)};
    int idx = 0;
    while (idx < queue.length) {
      final cur = queue[idx++];
      if (_getEdge(cur[0], cur[1], cur[2]) != oldValue) continue;
      _setEdgeValue(cur[0], cur[1], cur[2], newValue);
      final m = _sharedEdge(cur[0], cur[1], cur[2]);
      if (m != null) _setEdgeValue(m[0], m[1], m[2], newValue);
      for (final adj in _adjacentEdges(cur[0], cur[1], cur[2])) {
        if (_getEdge(adj[0], adj[1], adj[2]) == oldValue) {
          final id = _canonicalEdgeId(adj[0], adj[1], adj[2]);
          if (visited.add(id)) queue.add(adj);
        }
      }
    }
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
  static const int _solverMaxGuesses = 10;

  bool _solverRunning = false;
  bool _solverShouldStop = false;
  String _solverStatus = "";

  /// While true, [_applyConstraints] skips its expensive per-edge look-ahead
  /// pass and [_solverApplyAndCheck] skips deep-contradiction detection. Set
  /// only around answer-oracle moves: the oracle draws verified-correct edges,
  /// so the look-ahead / contradiction passes (each O(edges) hypotheses) are
  /// pure cosmetic overhead there — and they dominated auto-solve time.
  bool _solverFastApply = false;

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

    // 솔버 시작 시점 submit 스냅샷 — done 외 종료 시 보드 전체를 이 시점으로
    // 복원해 솔버가 남긴 +1 추측 라인, look-ahead -1 cascade, forced
    // disable (-4) 를 모두 폐기한다. 사용자가 직접 그어 두었던 ≥1/-2/-3/-4
    // 등은 스냅샷에 들어 있어 그대로 보존된다.
    final List<List<int>> preSolverSubmit =
        _readSubmit().map((r) => List<int>.from(r)).toList();

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

        // 정답 oracle 우선 (fast path). updateEdge 의 직접규칙 propagation 이
        // 보이는 자동 비활성(-1)을 처리하고, 비싼 per-edge contradiction 탐색과
        // look-ahead 는 _solverFastApply 로 건너뛴다 — oracle 이 완주를
        // 보장하므로 그 둘은 결과에 영향 없는 비용일 뿐이며 삼각형 자동풀기
        // 런타임을 지배했다. 정답에 있는데 아직 안 그은 변을 차례로 그어 완주.
        final List<int>? oracle = _solverNextOracleDraw();
        if (oracle != null) {
          _solverStatus = "solver_step";
          notifyListeners();
          _solverFastApply = true;
          final ok = await _solverApplyAndCheck(
              oracle[0], oracle[1], oracle[2], themeColor.getNormalRandom());
          _solverFastApply = false;
          if (_solverShouldStop) break;
          if (!ok) {
            if (!await _backtrackToLastGuess(guesses, stepDelay)) break;
          }
          await Future.delayed(stepDelay);
          continue;
        }

        // answer 부재 등 비정상 케이스의 안전망: 정답이 없으면 full deductive
        // 솔버 (contradiction 기반 forced 추론 + look-ahead, 그 뒤 추측) 로 푼다.
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

        // answer 부재 등 비정상 케이스의 안전망: 기존 추측 경로.
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
      _solverFastApply = false;
      // done 외 종료 시 pre-solver 시점으로 전체 복원. 솔버가 추가한 +1/-1/-4
      // 가 다음 사용자 탭의 propagation seed 가 되어 잘못된 cascade 를 만드는
      // 사고를 막는다 (SquareProvider 와 동일 정책).
      if (_solverStatus != "solver_done") {
        submit = preSolverSubmit.map((r) => List<int>.from(r)).toList();
        _applySubmit();
        _applyConstraints();
        submit = _readSubmit();
      }
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

  /// 정답에서 그어져야 하는데 아직 안 그어진 첫 변 [r, i, e]. 없으면 null.
  /// 솔버 oracle: 이 변들을 차례로 그으면 항상 정답으로 수렴한다.
  List<int>? _solverNextOracleDraw() {
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < triPerRow; i++) {
        for (int e = 0; e < 3; e++) {
          if (answer[r][i * 3 + e] == 1 && _getEdge(r, i, e) < 1) {
            return [r, i, e];
          }
        }
      }
    }
    return null;
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
    // oracle 수는 정답에서 검증된 변이라 deep-contradiction 검사가 불필요한
    // O(edges) 비용일 뿐 — fast path 에서는 건너뛴다.
    if (_solverFastApply) return true;
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
