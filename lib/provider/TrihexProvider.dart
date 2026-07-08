// ignore_for_file: file_names
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../MakePuzzle/TrihexGenerator.dart';
import '../widgets/TrihexBox.dart';
import '../Platform/ExtractData.dart'
  if (dart.library.html) '../Platform/ExtractDataWeb.dart';
import '../ThemeColor.dart';
import '../User/UserInfo.dart';
import '../l10n/app_localizations.dart';
import '../widgets/MainUI.dart';

/// Provider for the 3.6.3.6 trihexagonal puzzle.
///
/// Single source of truth is `edgeState : Map<edgeId, int>`. Sentinel values
/// match Square/Hexagon:
///   0   blank
///   1+  drawn (chain colour)
///   -1  auto-disabled by constraint propagation
///   -2  user-marked wrong
///   -3  hint highlight
///   -4  user-placed X
///   -5  wrong-hint flash
///
/// Topology uses encoded edge / vertex IDs from `TrihexGenerator`. Each
/// trihex edge is decoded back into its two vertex IDs on demand via
/// `1e9 % / ÷` (matches the encoder in `TrihexPuzzle.encodeEdge`).
class TrihexProvider with ChangeNotifier {
  late BuildContext context;
  final String loadKey;
  bool shutdown = false;
  bool isContinue = false;

  TrihexProvider({
    this.isContinue = false,
    required this.context,
    required this.loadKey,
  });

  ThemeColor themeColor = ThemeColor();

  /// Source of truth for clues and the geometry. Built from the answer
  /// format the scene generated/loaded. The puzzle's `activeEdges` is the
  /// solution; `edgeState` below tracks user input.
  late TrihexPuzzle puzzle;

  /// Trihex grid geometry helper. Reused by the box painter.
  late TrihexGenerator gen;

  /// User edge state, keyed by trihex edge ID.
  final Map<int, int> edgeState = {};

  int rows = 0;
  int cols = 0;

  /// Difficulty for hint masking.
  String difficulty = "normal";

  // --- Cached topology -----------------------------------------------------

  /// vertexId → list of incident edge IDs.
  final Map<int, List<int>> _edgesByVertex = {};

  /// hex cell index (r * cols + c) → 6 perimeter edge IDs.
  final List<List<int>> _hexEdgeIdsByCell = [];

  /// triangle id → 3 perimeter edge IDs.
  final Map<int, List<int>> _triEdgeIdsByCell = {};

  /// Every edge id in the grid. Built once in `_buildTopology`. Look-ahead
  /// iterates over this rather than `edgeState.keys` because untouched edges
  /// default to value 0 (undecided) and aren't in the map.
  final Set<int> _allEdges = {};

  /// Trihex vertex ID → canvas position (inside InteractiveViewer's child,
  /// i.e. includes the scene's outer EdgeInsets.all(20) padding). Populated
  /// once at `setAnswer`. Used by `getHintCanvasPos` so the scene can pan
  /// the InteractiveViewer to the freshly-placed hint edge.
  final Map<int, Offset> _vertexCanvasPos = {};

  /// Canvas position (same coordinate space as `_vertexCanvasPos`) of the
  /// most recently placed hint, or null if no hint is currently active.
  Offset? _hintCanvasPos;
  Offset? getHintCanvasPos() => _hintCanvasPos;

  // --- Undo/redo -----------------------------------------------------------

  final List<Map<int, int>> _undoStack = [];
  final List<Map<int, int>> _redoStack = [];

  void setAnswer(List<List<int>> answer) {
    puzzle = TrihexPuzzle.fromAnswerFormat(answer);
    rows = puzzle.rows;
    cols = puzzle.cols;
    gen = TrihexGenerator(rows, cols);
    _buildTopology();
    _buildVertexCanvasPositions();
  }

  /// Mirrors `_TrihexLayout.build` in TrihexBox so we can resolve any trihex
  /// vertex ID to a canvas Offset (for the pan-to-hint feature). Includes
  /// the scene's outer Padding(20) so the offset matches the InteractiveViewer
  /// child coordinate system.
  void _buildVertexCanvasPositions() {
    _vertexCanvasPos.clear();
    const double R = TrihexBox.cellSize;
    final double w = R * sqrt(3);
    const double padding = R;
    const double scenePadding = 20.0;

    Offset hexCenter(int r, int c) {
      final double x = padding + w * c + (r & 1) * (w / 2) + w / 2;
      final double y = padding + R * 1.5 * r + R;
      return Offset(scenePadding + x, scenePadding + y);
    }

    Offset hexVertex(int r, int c, int vi) {
      final ctr = hexCenter(r, c);
      switch (vi) {
        case 0: return Offset(ctr.dx, ctr.dy - R);
        case 1: return Offset(ctr.dx + w / 2, ctr.dy - R / 2);
        case 2: return Offset(ctr.dx + w / 2, ctr.dy + R / 2);
        case 3: return Offset(ctr.dx, ctr.dy + R);
        case 4: return Offset(ctr.dx - w / 2, ctr.dy + R / 2);
        case 5: return Offset(ctr.dx - w / 2, ctr.dy - R / 2);
      }
      return ctr;
    }

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final mids = gen.hexCellVerticesOf(r, c);
        for (int i = 0; i < 6; i++) {
          final a = hexVertex(r, c, i);
          final b = hexVertex(r, c, (i + 1) % 6);
          _vertexCanvasPos[mids[i]] =
              Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
        }
      }
    }
  }

  Offset? _edgeMidpoint(int edgeId) {
    final int hi = edgeId % 1000000000;
    final int lo = edgeId ~/ 1000000000;
    final a = _vertexCanvasPos[lo];
    final b = _vertexCanvasPos[hi];
    if (a == null || b == null) return null;
    return Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
  }

  /// Cache cell→edges and vertex→edges adjacency. Called once after
  /// `setAnswer` so the rule passes don't recompute trihex geometry.
  void _buildTopology() {
    _edgesByVertex.clear();
    _hexEdgeIdsByCell.clear();
    _triEdgeIdsByCell.clear();
    _allEdges.clear();

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final edges = gen.hexCellEdgesOf(r, c);
        _hexEdgeIdsByCell.add(edges);
        _allEdges.addAll(edges);
      }
    }
    final tri = gen.enumerateTriangles();
    for (final id in puzzle.triangleIds) {
      final rep = tri.rep[id]!;
      final edges = gen.triangleEdgesOf(rep[0], rep[1], rep[2]);
      _triEdgeIdsByCell[id] = edges;
      _allEdges.addAll(edges);
    }
    for (final e in _allEdges) {
      final int hi = e % 1000000000;
      final int lo = e ~/ 1000000000;
      _edgesByVertex.putIfAbsent(lo, () => []).add(e);
      _edgesByVertex.putIfAbsent(hi, () => []).add(e);
    }
  }

  void setSubmit(List<List<int>> submit) {
    edgeState.clear();
    if (submit.isEmpty) return;
    if (submit.length < 2) return;
    final List<int> hexFlat = submit[0];
    final List<int> triFlat = submit[1];
    int eIdx = 0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final perim = gen.hexCellEdgesOf(r, c);
        for (int k = 0; k < 6; k++) {
          final v = eIdx < hexFlat.length ? hexFlat[eIdx] : 0;
          if (v != 0) edgeState[perim[k]] = v;
          eIdx++;
        }
      }
    }
    final tri = gen.enumerateTriangles();
    int teIdx = 0;
    for (final id in puzzle.triangleIds) {
      final rep = tri.rep[id]!;
      final perim = gen.triangleEdgesOf(rep[0], rep[1], rep[2]);
      for (int k = 0; k < 3; k++) {
        final v = teIdx < triFlat.length ? triFlat[teIdx] : 0;
        if (v != 0) edgeState[perim[k]] = v;
        teIdx++;
      }
    }
  }

  void setDifficulty(String d) {
    difficulty = d;
  }

  Future<void> init() async {
    _maskByDifficulty();
    // 갓 로드된 보드는 단서만 보여준다. _applyConstraints 의 look-ahead 추론까지
    // 돌리면 풀 수 없는 대량의 edge 가 즉시 -1 로 칠해지며 정답 라인이 첫
    // 화면에 드러난다(스포일러). 자명한 직접규칙(_propagateDirect)만 적용하고,
    // 깊은 추론은 사용자 첫 수에 updateEdge → _applyConstraints 에서 나타난다.
    _propagateDirect();
    notifyListeners();
  }

  /// Hide a deterministic subset of clue cells based on difficulty. Same
  /// strategy as HexagonProvider — seeded by the answer hash so Continue
  /// reproduces the mask without storing it.
  void _maskByDifficulty() {
    double ratio;
    switch (difficulty) {
      case "easy": ratio = 0.80; break;
      case "hard": ratio = 0.35; break;
      default: ratio = 0.55;
    }
    if (ratio >= 1.0) return;

    int seed = 0;
    void hash(int v) { seed = (seed * 31 + v) & 0x7FFFFFFF; }
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        hash(puzzle.hexClue[r][c]);
      }
    }
    for (final id in puzzle.triangleIds) {
      hash(puzzle.triClue[id] ?? -1);
    }

    final List<List<int>> cells = [];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        cells.add([0, r, c]);
      }
    }
    for (final id in puzzle.triangleIds) {
      cells.add([1, id, 0]);
    }
    cells.shuffle(Random(seed));

    final int keep = (cells.length * ratio).round();
    for (int i = keep; i < cells.length; i++) {
      final cell = cells[i];
      if (cell[0] == 0) {
        puzzle.hexClue[cell[1]][cell[2]] = -1;
      } else {
        puzzle.triClue[cell[1]] = -1;
      }
    }
  }

  /// Read user state for the given edge ID (0 if unset).
  int edgeValue(int edgeId) => edgeState[edgeId] ?? 0;

  /// Apply a tap. Handles chain colour merging, then runs the constraint
  /// fixed-point and the completion check.
  Future<void> updateEdge(int edgeId, int value) async {
    _undoStack.add(_snapshot());
    _redoStack.clear();

    int finalValue = value;
    if (value >= 1) {
      final adj = _adjacentEdges(edgeId);
      final Set<int> nearColors = {};
      for (final a in adj) {
        final v = edgeValue(a);
        if (v >= 1) nearColors.add(v);
      }
      if (nearColors.isNotEmpty) {
        finalValue = nearColors.first;
        for (final a in adj) {
          final v = edgeValue(a);
          if (v >= 1 && v != finalValue) {
            _recolorChain(a, finalValue);
          }
        }
      }
    }

    if (finalValue == 0) {
      edgeState.remove(edgeId);
    } else {
      edgeState[edgeId] = finalValue;
    }
    _applyConstraints();
    notifyListeners();

    _checkComplete();
  }

  /// Cycle behaviour mirrors HexagonBox/SquareBox so the tap loop feels
  /// the same across puzzle types.
  ///   0/-3 → fresh chain colour
  ///   colour/-5 → -4 (X)
  ///   -1 → -2 (mark "I disagree with the auto-disable")
  ///   -2 → -1 (revert to auto-disabled)
  ///   -4 → 0
  int cycleEdge(int current) {
    if (current == 0 || current == -3) return ThemeColor().getNormalRandom();
    if (current >= 1 || current == -5) return -4;
    if (current == -1) return -2;
    if (current == -2) return -1;
    if (current == -4) return 0;
    return 0;
  }

  // --- Adjacency / chain colouring ----------------------------------------

  /// All edges sharing a vertex with `edgeId`, excluding the edge itself.
  List<int> _adjacentEdges(int edgeId) {
    final int hi = edgeId % 1000000000;
    final int lo = edgeId ~/ 1000000000;
    final Set<int> out = {};
    for (final v in [lo, hi]) {
      for (final e in (_edgesByVertex[v] ?? const [])) {
        if (e != edgeId) out.add(e);
      }
    }
    return out.toList();
  }

  /// BFS from `seed` recolouring every drawn edge reachable through the
  /// current colour into `newColor`.
  void _recolorChain(int seed, int newColor) {
    final int oldColor = edgeValue(seed);
    if (oldColor == newColor || oldColor < 1) return;
    final List<int> queue = [seed];
    final Set<int> visited = {seed};
    int idx = 0;
    while (idx < queue.length) {
      final e = queue[idx++];
      if (edgeValue(e) != oldColor) continue;
      edgeState[e] = newColor;
      for (final adj in _adjacentEdges(e)) {
        if (edgeValue(adj) == oldColor && visited.add(adj)) {
          queue.add(adj);
        }
      }
    }
  }

  // --- Constraint propagation ---------------------------------------------

  /// Wipe prior auto-disables (-1) and iterate cell + vertex rules until
  /// a fixed point, then run a 1-step look-ahead pass: each undecided edge
  /// is hypothetically drawn and propagated; if the hypothesis triggers a
  /// contradiction (a clue would over-fill, or a vertex would exceed degree
  /// 2) the edge is flagged -1.
  ///
  /// User red marks (-2) are also cleared alongside -1 so look-ahead doesn't
  /// lock them as hard premises (which would cascade-disable adjacent edges).
  /// After propagation, -2 is restored at edge ids whose new value is -1.
  /// User X marks (-4) are hard locks and not touched.
  ///
  /// Global-infeasibility guard: if the user X-marks a drawn line that was
  /// critical to satisfying some clue (the cell now can't reach `num`), the
  /// puzzle becomes globally infeasible. In that state look-ahead concludes
  /// "every undecided edge contradicts" and disables the whole board. To
  /// prevent that, we snapshot the full edgeState at entry; if propagation
  /// ends in a locally inconsistent state (caught by _isStateConsistent),
  /// we restore from snapshot. The user's tap is preserved (it was in the
  /// snapshot) but no cascade -1 is applied. See docs §4 / §5 for context.
  void _applyConstraints() {
    final List<int> redSnapshot = [];
    edgeState.forEach((id, v) {
      if (v == -2) redSnapshot.add(id);
    });
    edgeState.removeWhere((_, v) => v == -1 || v == -2);

    // Capture consistency AFTER clearing -1/-2 so it reflects what propagation
    // actually sees. If the user already put the board into an inconsistent
    // state (e.g. over-drew a num=1 cell), direct-rule cascade is local and
    // we want it to run — that's how the user gets the visual "you can't draw
    // here" feedback. Only revert when propagation TURNED a previously-OK
    // state into an inconsistent one (e.g. look-ahead wiping the board after
    // a critical X-mark — see docs §4-3-1).
    final bool entryConsistent = _isStateConsistent();

    _propagateDirect();

    // Direct rule 만으로 도출된 결과는 보존한다 — look-ahead 가 hidden-clue
    // 환경에서 잘못 발화해 모순을 만들면 revert 는 여기까지로만 되돌린다.
    // guardSnap (entry) 까지 가면 init 직후 0-clue 자동 -1 표시가 사라진다.
    final Map<int, int> afterDirect = Map<int, int>.from(edgeState);

    // 자동풀기 oracle 수에서는 look-ahead 를 건너뛴다 (per-edge 가설 →
    // O(edges) 비용). oracle 이 정답을 보장하므로 look-ahead 의 추가 -1 표시는
    // cosmetic 일 뿐이고, 이 패스가 Trihex 자동풀기 속도를 좌우했다. 사용자 탭/
    // backtrack/init 등 _solverFastApply 가 꺼진 경로에서는 그대로 동작한다.
    if (!_solverFastApply) {
      for (int laIter = 0; laIter < 5; laIter++) {
        if (!_runLookAhead()) break;
        _propagateDirect();
      }
    }

    for (final id in redSnapshot) {
      if (edgeState[id] == -1) {
        edgeState[id] = -2;
      }
    }

    if (entryConsistent && !_isStateConsistent()) {
      _restore(afterDirect);
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

  /// Cell rule: when a clue cell has `clue` selected edges (value ≥ 1),
  /// any remaining undecided edges (value == 0) are auto-disabled (-1).
  /// Hidden clues (clue < 0) are skipped.
  bool _runCellRule() {
    bool any = false;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final clue = puzzle.hexClue[r][c];
        if (clue < 0) continue;
        final edges = _hexEdgeIdsByCell[r * cols + c];
        int active = 0;
        for (final e in edges) {
          if (edgeValue(e) >= 1) active++;
        }
        if (active < clue) continue;
        for (final e in edges) {
          if (edgeValue(e) == 0) {
            edgeState[e] = -1;
            any = true;
          }
        }
      }
    }
    for (final id in puzzle.triangleIds) {
      final clue = puzzle.triClue[id] ?? -1;
      if (clue < 0) continue;
      final edges = _triEdgeIdsByCell[id]!;
      int active = 0;
      for (final e in edges) {
        if (edgeValue(e) >= 1) active++;
      }
      if (active < clue) continue;
      for (final e in edges) {
        if (edgeValue(e) == 0) {
          edgeState[e] = -1;
          any = true;
        }
      }
    }
    return any;
  }

  /// Vertex-degree rule: every Slitherlink vertex must end at degree 0 or 2.
  /// If two edges at a vertex are already drawn, remaining undecideds become
  /// -1. If active + undecided < 2, the vertex is starved — undecideds are
  /// also disabled.
  bool _runVertexRule() {
    bool any = false;
    for (final edges in _edgesByVertex.values) {
      int active = 0, undecided = 0;
      for (final e in edges) {
        final v = edgeValue(e);
        if (v >= 1) {
          active++;
        } else if (v == 0) {
          undecided++;
        }
      }
      final satisfied = active >= 2;
      final starved = active + undecided < 2;
      if (!satisfied && !starved) continue;
      for (final e in edges) {
        if (edgeValue(e) == 0) {
          edgeState[e] = -1;
          any = true;
        }
      }
    }
    return any;
  }

  /// Returns true iff the live puzzle state already violates a hard
  /// constraint. See HexagonProvider._isStateConsistent for the rationale.
  bool _isStateConsistent() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final clue = puzzle.hexClue[r][c];
        if (clue < 0) continue;
        final edges = _hexEdgeIdsByCell[r * cols + c];
        int active = 0, undecided = 0;
        for (final e in edges) {
          final v = edgeValue(e);
          if (v >= 1) {
            active++;
          } else if (v == 0) {
            undecided++;
          }
        }
        if (active > clue) return false;
        if (active + undecided < clue) return false;
      }
    }
    for (final id in puzzle.triangleIds) {
      final clue = puzzle.triClue[id] ?? -1;
      if (clue < 0) continue;
      final edges = _triEdgeIdsByCell[id]!;
      int active = 0, undecided = 0;
      for (final e in edges) {
        final v = edgeValue(e);
        if (v >= 1) {
          active++;
        } else if (v == 0) {
          undecided++;
        }
      }
      if (active > clue) return false;
      if (active + undecided < clue) return false;
    }
    for (final edges in _edgesByVertex.values) {
      int active = 0, undecided = 0;
      for (final e in edges) {
        final v = edgeValue(e);
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

  /// Look-ahead pass. For each undecided edge: snapshot edgeState,
  /// hypothesise the edge as drawn (=1), run a hypothetical propagator that
  /// adds force-draw rules and contradiction detection, then restore. If the
  /// hypothesis broke a clue or vertex constraint, the actual edge is
  /// flagged -1.
  bool _runLookAhead() {
    if (!_isStateConsistent()) return false;
    bool any = false;
    for (final e in _allEdges) {
      if (edgeValue(e) != 0) continue;
      final snap = _snapshot();
      edgeState[e] = 1;
      final contradiction = _propagateHypothesis();
      _restore(snap);
      if (contradiction) {
        edgeState[e] = -1;
        any = true;
      }
    }
    return any;
  }

  /// Hypothetical propagator used inside _runLookAhead. Mutates edgeState
  /// freely — caller must snapshot+restore. Returns true on contradiction.
  bool _propagateHypothesis() {
    for (int iter = 0; iter < 30; iter++) {
      bool changed = false;

      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          final clue = puzzle.hexClue[r][c];
          if (clue < 0) continue;
          final edges = _hexEdgeIdsByCell[r * cols + c];
          int active = 0, undecided = 0;
          for (final e in edges) {
            final v = edgeValue(e);
            if (v >= 1) {
              active++;
            } else if (v == 0) {
              undecided++;
            }
          }
          if (active > clue) return true;
          if (active + undecided < clue) return true;
          if (active == clue && undecided > 0) {
            for (final e in edges) {
              if (edgeValue(e) == 0) {
                edgeState[e] = -1;
                changed = true;
              }
            }
          } else if (active + undecided == clue && undecided > 0) {
            for (final e in edges) {
              if (edgeValue(e) == 0) {
                edgeState[e] = 1;
                changed = true;
              }
            }
          }
        }
      }

      for (final id in puzzle.triangleIds) {
        final clue = puzzle.triClue[id] ?? -1;
        if (clue < 0) continue;
        final edges = _triEdgeIdsByCell[id]!;
        int active = 0, undecided = 0;
        for (final e in edges) {
          final v = edgeValue(e);
          if (v >= 1) {
            active++;
          } else if (v == 0) {
            undecided++;
          }
        }
        if (active > clue) return true;
        if (active + undecided < clue) return true;
        if (active == clue && undecided > 0) {
          for (final e in edges) {
            if (edgeValue(e) == 0) {
              edgeState[e] = -1;
              changed = true;
            }
          }
        } else if (active + undecided == clue && undecided > 0) {
          for (final e in edges) {
            if (edgeValue(e) == 0) {
              edgeState[e] = 1;
              changed = true;
            }
          }
        }
      }

      for (final edges in _edgesByVertex.values) {
        int active = 0, undecided = 0;
        for (final e in edges) {
          final v = edgeValue(e);
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
            if (edgeValue(e) == 0) {
              edgeState[e] = -1;
              changed = true;
            }
          }
        } else if (active == 0 && undecided > 0 && undecided < 2) {
          for (final e in edges) {
            if (edgeValue(e) == 0) {
              edgeState[e] = -1;
              changed = true;
            }
          }
        } else if (active == 1 && undecided == 1) {
          for (final e in edges) {
            if (edgeValue(e) == 0) {
              edgeState[e] = 1;
              changed = true;
            }
          }
        }
      }

      if (!changed) {
        // 수렴 시점에만 전역 고리 위상 검사 (partial 상태의 transient 닫힌
        // 고리 오판 방지). HexagonProvider._propagateHypothesis 와 동일 규칙.
        if (_hasInconsistentLoopTopology()) return true;
        break;
      }
    }
    return false;
  }

  /// 그어진 변(>=1)들의 연결 성분을 union-find 로 추적해 전역 고리 위상을
  /// 검사한다. edge id 는 두 끝점 vertex 를 (lo, hi) 로 인코딩하므로 추가
  /// geometry 조회 없이 바로 union 한다. 닫힌 고리가 2개 이상이거나 닫힌 고리
  /// 1개 + 다른 성분이 더 있으면 위상 모순(true).
  bool _hasInconsistentLoopTopology() {
    final Map<int, int> parent = {};
    int find(int x) {
      parent.putIfAbsent(x, () => x);
      int root = x;
      while (parent[root] != root) {
        root = parent[root]!;
      }
      while (parent[x] != root) {
        final next = parent[x]!;
        parent[x] = root;
        x = next;
      }
      return root;
    }

    final Map<int, int> deg = {};
    for (final e in _allEdges) {
      if (edgeValue(e) < 1) continue;
      final int a = e ~/ 1000000000;
      final int b = e % 1000000000;
      deg[a] = (deg[a] ?? 0) + 1;
      deg[b] = (deg[b] ?? 0) + 1;
      final ra = find(a);
      final rb = find(b);
      if (ra != rb) parent[ra] = rb;
    }
    if (deg.isEmpty) return false;

    final Map<int, bool> closedFlag = {};
    for (final v in deg.keys) {
      final root = find(v);
      final bool d2 = deg[v] == 2;
      if (!closedFlag.containsKey(root)) {
        closedFlag[root] = d2;
      } else if (!d2) {
        closedFlag[root] = false;
      }
    }
    int closed = 0;
    for (final f in closedFlag.values) {
      if (f) closed++;
    }
    if (closed >= 2) return true;
    if (closed == 1 && closedFlag.length > 1) return true;
    return false;
  }

  /// 그어진 변이 정확히 하나의 닫힌 고리를 이루는지 (정답 비참조 완료 판정용).
  bool _isSingleClosedLoop() {
    final Map<int, int> parent = {};
    int find(int x) {
      parent.putIfAbsent(x, () => x);
      int root = x;
      while (parent[root] != root) {
        root = parent[root]!;
      }
      while (parent[x] != root) {
        final next = parent[x]!;
        parent[x] = root;
        x = next;
      }
      return root;
    }

    final Map<int, int> deg = {};
    int drawn = 0;
    for (final e in _allEdges) {
      if (edgeValue(e) < 1) continue;
      drawn++;
      final int a = e ~/ 1000000000;
      final int b = e % 1000000000;
      deg[a] = (deg[a] ?? 0) + 1;
      deg[b] = (deg[b] ?? 0) + 1;
      final ra = find(a);
      final rb = find(b);
      if (ra != rb) parent[ra] = rb;
    }
    if (drawn == 0) return false;
    for (final v in deg.keys) {
      if (deg[v] != 2) return false;
    }
    final Set<int> roots = {};
    for (final v in deg.keys) {
      roots.add(find(v));
    }
    return roots.length == 1;
  }

  // --- Completion ---------------------------------------------------------

  void _checkComplete() {
    for (final e in puzzle.activeEdges) {
      if (edgeValue(e) < 1) return;
    }
    for (final entry in edgeState.entries) {
      if (entry.value >= 1 && !puzzle.activeEdges.contains(entry.key)) return;
    }
    showComplete(context);
  }

  // --- Snapshot / I/O -----------------------------------------------------

  Map<int, int> _snapshot() => Map<int, int>.from(edgeState);

  void _restore(Map<int, int> snap) {
    edgeState.clear();
    edgeState.addAll(snap);
  }

  /// Snapshot user edge state into the same flat layout `setSubmit` reads.
  List<List<int>> readSubmit() {
    final List<int> hexFlat = [];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        for (final e in gen.hexCellEdgesOf(r, c)) {
          hexFlat.add(edgeValue(e));
        }
      }
    }
    final List<int> triFlat = [];
    final tri = gen.enumerateTriangles();
    for (final id in puzzle.triangleIds) {
      final rep = tri.rep[id]!;
      for (final e in gen.triangleEdgesOf(rep[0], rep[1], rep[2])) {
        triFlat.add(edgeValue(e));
      }
    }
    return [hexFlat, triFlat];
  }

  Future<void> saveProgress() async {
    // Hint (-3) and wrong-flash (-5) markers are ephemeral — drop them
    // before persisting so Continue doesn't resurrect a stale flash.
    await removeHintLine();
    final prefs = ExtractData();
    await prefs.saveDataToLocal(
      "${MainUI.getProgressKey()}_continue",
      jsonEncode(readSubmit()),
    );
  }

  // --- User-triggered actions --------------------------------------------

  Future<void> undo() async {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_snapshot());
    _restore(_undoStack.removeLast());
    _applyConstraints();
    notifyListeners();
  }

  Future<void> redo() async {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_snapshot());
    _restore(_redoStack.removeLast());
    _applyConstraints();
    notifyListeners();
  }

  Future<void> restart() async {
    // 자동 풀기 중이었다면 먼저 중단 — restart 가 edgeState 를 비우는데
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
    edgeState.clear();
    _applyConstraints();
    notifyListeners();
  }

  /// Highlight one missing answer edge with -3 so the painter can flash it,
  /// and stash its canvas position for the scene to pan to.
  Future<void> showHint(BuildContext context) async {
    for (final e in puzzle.activeEdges) {
      final v = edgeValue(e);
      if (v <= 0) {
        edgeState[e] = -3;
        _hintCanvasPos = _edgeMidpoint(e);
        notifyListeners();
        return;
      }
    }
  }

  Future<void> removeHintLine() async {
    edgeState.removeWhere((_, v) => v == -3 || v == -5);
    _hintCanvasPos = null;
  }

  List<List<int>> snapshotSubmit() => readSubmit();

  /// Apply a previously-saved submit grid (from a bookmark load).
  /// Treated as a single edit step: the pre-load state is pushed onto the
  /// undo stack so the user can undo back, and the redo stack is dropped
  /// because we're branching forward from the user's current position.
  Future<void> applyBookmarkSubmit(List<List<int>> newSubmit) async {
    await removeHintLine();
    _undoStack.add(_snapshot());
    _redoStack.clear();
    setSubmit(newSubmit);
    _applyConstraints();
    notifyListeners();
  }

  /// Fired by `_checkComplete` once user submission matches `puzzle.activeEdges`.
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

  ///**********************************************************************************
  ///****************** human-like auto solver ******************
  ///**********************************************************************************
  /// Square / Triangle / Hexagon 솔버와 동일 골격이지만 Trihex 는 edgeState 가
  /// Map<edgeId,int> 라 snapshot/restore 는 Map 복사 한 번이면 끝난다.
  /// 추측 frame 도 edgeState snapshot 만 들고 있으면 충분. 정답 oracle 제거 후
  /// 추측+백트래킹이 유일한 풀이 동력이므로 깊이 상한을 크게 둬 완전 탐색을
  /// 보장하고, 무한 루프는 solveHumanLike 의 총 iter 상한으로 막는다.
  static const int _solverMaxGuesses = 100000;

  bool _solverRunning = false;
  bool _solverShouldStop = false;
  String _solverStatus = "";

  /// While true, [_applyConstraints] skips its expensive per-edge look-ahead
  /// pass and [_solverApplyAndCheck] skips deep-contradiction detection. Set
  /// only around answer-oracle moves: the oracle draws verified-correct edges,
  /// so the look-ahead / contradiction passes (each O(edges) hypotheses) are
  /// pure cosmetic overhead there — and they dominated Trihex auto-solve time.
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

    final List<_TrihexGuessFrame> guesses = [];

    // 솔버 시작 시점 edgeState 스냅샷 — done 외 종료 시 보드 전체를 이 시점으로
    // 복원해 솔버가 남긴 +1 추측 라인, look-ahead -1 cascade, forced disable
    // (-4) 를 모두 폐기한다. 사용자가 직접 그어 두었던 entry 는 스냅샷에
    // 들어 있어 그대로 보존된다 (SquareProvider 와 동일 정책).
    final Map<int, int> preSolverEdgeState = _snapshot();

    // 정답 oracle 제거로 종료 보장이 사라져 외부 안전망을 둔다.
    const int kMaxIter = 20000;
    const int kMaxNoProgress = 400;
    int iterCount = 0;
    int noProgressStreak = 0;

    try {
      while (!_solverShouldStop) {
        if (++iterCount > kMaxIter || noProgressStreak > kMaxNoProgress) {
          _solverStatus = "solver_stuck";
          notifyListeners();
          break;
        }
        if (_isPuzzleSolvedLocal()) {
          _solverStatus = "solver_done";
          notifyListeners();
          break;
        }

        if (!_isStateConsistent() || _hasInconsistentLoopTopology()) {
          if (!await _backtrackToLastGuess(guesses, stepDelay)) break;
          await Future.delayed(stepDelay);
          continue;
        }

        // 정답을 보지 않고 화면 단서만으로 푼다 (사용자 관점). 모순 기반 forced
        // 추론을 먼저 적용하고, 확정이 없으면 영향력 최대 변으로 추측 후 모순
        // 시 백트래킹한다.
        final int? draw = _findForcedDrawByContradiction();
        if (draw != null) {
          _solverStatus = "solver_step";
          notifyListeners();
          final ok =
              await _solverApplyAndCheck(draw, themeColor.getNormalRandom());
          if (_solverShouldStop) break;
          if (!ok) {
            if (!await _backtrackToLastGuess(guesses, stepDelay)) break;
          }
          noProgressStreak = 0;
          await Future.delayed(stepDelay);
          continue;
        }

        final int? disable = _findForcedDisableByContradiction();
        if (disable != null) {
          _solverStatus = "solver_step";
          notifyListeners();
          final ok = await _solverApplyAndCheck(disable, -4);
          if (_solverShouldStop) break;
          if (!ok) {
            if (!await _backtrackToLastGuess(guesses, stepDelay)) break;
          }
          noProgressStreak = 0;
          await Future.delayed(stepDelay);
          continue;
        }

        // 확정 없음 → 영향력이 가장 큰 edge 로 추측 후 백트래킹.
        if (guesses.length >= _solverMaxGuesses) {
          _solverStatus = "solver_labels_full";
          notifyListeners();
          break;
        }
        final int? guess = _pickHighestImpactGuess();
        if (guess == null) {
          _solverStatus = "solver_stuck";
          notifyListeners();
          break;
        }
        final snap = _snapshot();
        guesses.add(_TrihexGuessFrame(snap, guess));
        _solverStatus = "solver_guess";
        notifyListeners();
        final ok =
            await _solverApplyAndCheck(guess, themeColor.getNormalRandom());
        if (_solverShouldStop) break;
        if (!ok) {
          if (!await _backtrackToLastGuess(guesses, stepDelay)) break;
        }
        noProgressStreak++;
        await Future.delayed(stepDelay);
      }
    } finally {
      _solverRunning = false;
      _solverFastApply = false;
      // done 외 종료 시 pre-solver 시점으로 전체 복원.
      if (_solverStatus != "solver_done") {
        _restore(preSolverEdgeState);
        _applyConstraints();
      }
      notifyListeners();
    }
  }

  /// 정답(activeEdges)을 보지 않는 완료 판정: 그어진 변이 단일 닫힌 고리를
  /// 이루고, 보이는 모든 단서(hex/triangle, clue<0 숨김 제외)가 정확히
  /// 충족되면 완료.
  bool _isPuzzleSolvedLocal() {
    if (!_isSingleClosedLoop()) return false;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final int clue = puzzle.hexClue[r][c];
        if (clue < 0) continue;
        int active = 0;
        for (final e in _hexEdgeIdsByCell[r * cols + c]) {
          if (edgeValue(e) >= 1) active++;
        }
        if (active != clue) return false;
      }
    }
    for (final id in puzzle.triangleIds) {
      final int clue = puzzle.triClue[id] ?? -1;
      if (clue < 0) continue;
      int active = 0;
      for (final e in _triEdgeIdsByCell[id]!) {
        if (edgeValue(e) >= 1) active++;
      }
      if (active != clue) return false;
    }
    return true;
  }

  /// 정답(activeEdges)을 보지 않고, 보이는 단서만으로 추측 없이 끝까지 풀리는지
  /// (공정한 퍼즐 검증). 직접규칙 전파 + 모순기반 forced draw/disable + 고리위상
  /// 검사만 반복 적용한다. 계산 후 원래 edgeState 로 복원하므로 보드를 바꾸지
  /// 않는다.
  bool isLogicSolvable() {
    final snap = _snapshot();
    bool result = false;
    const int maxIter = 100000;
    for (int iter = 0; iter < maxIter; iter++) {
      _propagateDirect();
      if (!_isStateConsistent() || _hasInconsistentLoopTopology()) {
        result = false;
        break;
      }
      if (_isPuzzleSolvedLocal()) {
        result = true;
        break;
      }
      final int? draw = _findForcedDrawByContradiction();
      if (draw != null) {
        edgeState[draw] = 1;
        continue;
      }
      final int? disable = _findForcedDisableByContradiction();
      if (disable != null) {
        edgeState[disable] = -1;
        continue;
      }
      result = false; // 확정 수 없음 → 추측 필요 → 불공정
      break;
    }
    _restore(snap);
    return result;
  }

  /// 백그라운드 검증용: 화면 자동풀기와 동일한 추측+백트래킹 완전탐색을
  /// headless 로 돌려 풀리는지 확인한다. 메인 스레드 엔진이라 시간 분할(주기적
  /// yield)로 UI 를 막지 않고, 시간/노드 예산 초과(미결)는 수용(true).
  /// 정답(activeEdges) 비참조(완료판정 단일고리+단서), 고리위상 검사 포함,
  /// 계산 후 edgeState 원복으로 보드를 바꾸지 않는다.
  Future<bool> canAutoSolve() async {
    final sw = Stopwatch()..start();
    const Duration budget = Duration(milliseconds: 1200);
    final outer = _snapshot();
    final List<List<dynamic>> stack = []; // [snapshot(Map), edgeId]
    bool result = false;
    bool inconclusive = false;
    const int maxIter = 200000;
    const int maxNoProg = 3000;
    int iter = 0;
    int noProg = 0;
    while (true) {
      if (iter++ > maxIter || noProg > maxNoProg || sw.elapsed > budget) {
        inconclusive = true;
        break;
      }
      if ((iter & 0xFF) == 0) await Future.delayed(Duration.zero); // UI 양보
      _propagateDirect();
      if (!_isStateConsistent() || _hasInconsistentLoopTopology()) {
        if (stack.isEmpty) break;
        final f = stack.removeLast();
        _restore(f[0] as Map<int, int>);
        edgeState[f[1] as int] = -1;
        continue;
      }
      if (_isPuzzleSolvedLocal()) {
        result = true;
        break;
      }
      final int? draw = _findForcedDrawByContradiction();
      if (draw != null) {
        edgeState[draw] = 1;
        noProg = 0;
        continue;
      }
      final int? dis = _findForcedDisableByContradiction();
      if (dis != null) {
        edgeState[dis] = -1;
        noProg = 0;
        continue;
      }
      final int? guess = _pickHighestImpactGuess();
      if (guess == null) {
        if (stack.isEmpty) break;
        final f = stack.removeLast();
        _restore(f[0] as Map<int, int>);
        edgeState[f[1] as int] = -1;
        continue;
      }
      stack.add([_snapshot(), guess]);
      edgeState[guess] = 1;
      noProg++;
    }
    _restore(outer);
    return result || inconclusive; // 미결이면 수용(멈춤 방지)
  }

  Future<bool> _backtrackToLastGuess(
      List<_TrihexGuessFrame> guesses, Duration stepDelay) async {
    if (guesses.isEmpty) {
      _solverStatus = "solver_stuck";
      notifyListeners();
      return false;
    }
    final frame = guesses.removeLast();
    _solverStatus = "solver_backtrack";
    notifyListeners();

    _undoStack.add(_snapshot());
    _redoStack.clear();
    _restore(frame.snapshot);
    _applyConstraints();
    notifyListeners();

    await Future.delayed(stepDelay);
    if (_solverShouldStop) return true;

    await updateEdge(frame.edgeId, -4);
    return true;
  }

  Future<bool> _solverApplyAndCheck(int edgeId, int value) async {
    await updateEdge(edgeId, value);
    if (_solverShouldStop) return true;
    // oracle 수는 정답 edge 라 deep contradiction 이 날 수 없다 — 한 번 더
    // 도는 _propagateHypothesis 비용을 생략한다.
    if (_solverFastApply) return true;
    return !_detectDeepContradiction();
  }

  bool _detectDeepContradiction() {
    final snap = _snapshot();
    final contra = _propagateHypothesis();
    _restore(snap);
    return contra;
  }

  int? _findForcedDrawByContradiction() {
    for (final e in _allEdges) {
      if (edgeValue(e) != 0) continue;

      final snap = _snapshot();
      edgeState[e] = -1;
      final contra = _propagateHypothesis();
      _restore(snap);

      if (contra) return e;
    }
    return null;
  }

  int? _findForcedDisableByContradiction() {
    for (final e in _allEdges) {
      if (edgeValue(e) != 0) continue;

      final snap = _snapshot();
      edgeState[e] = 1;
      final contra = _propagateHypothesis();
      _restore(snap);

      if (contra) return e;
    }
    return null;
  }

  /// +1 가설 propagation 으로 변화량이 가장 큰 undecided edge 반환.
  /// contradiction 인 edge 는 "확정 -1" 이므로 추측 후보에서 제외 —
  /// docs/auto_solver_bug_analysis.md §1 의 contradiction-as-guess 트랩 방지.
  int? _pickHighestImpactGuess() {
    int bestScore = -1;
    int? best;
    for (final e in _allEdges) {
      if (edgeValue(e) != 0) continue;

      final snap = _snapshot();
      edgeState[e] = 1;
      final contra = _propagateHypothesis();

      int changes = 0;
      if (!contra) {
        // edgeState 의 set/unset 모두 카운트. 0 (undefined) 은 unset 으로 본다.
        final Set<int> keys = {...snap.keys, ...edgeState.keys};
        for (final k in keys) {
          if ((snap[k] ?? 0) != (edgeState[k] ?? 0)) changes++;
        }
      }
      _restore(snap);

      if (contra) continue;
      if (changes > bestScore) {
        bestScore = changes;
        best = e;
      }
    }
    return best;
  }
}

class _TrihexGuessFrame {
  final Map<int, int> snapshot;
  final int edgeId;
  _TrihexGuessFrame(this.snapshot, this.edgeId);
}
