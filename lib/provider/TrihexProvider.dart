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

    final Set<int> allEdges = {};
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final edges = gen.hexCellEdgesOf(r, c);
        _hexEdgeIdsByCell.add(edges);
        allEdges.addAll(edges);
      }
    }
    final tri = gen.enumerateTriangles();
    for (final id in puzzle.triangleIds) {
      final rep = tri.rep[id]!;
      final edges = gen.triangleEdgesOf(rep[0], rep[1], rep[2]);
      _triEdgeIdsByCell[id] = edges;
      allEdges.addAll(edges);
    }
    for (final e in allEdges) {
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
    _applyConstraints();
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
  /// a fixed point. User annotations (-2 wrong, -4 X, -3/-5 hint) survive.
  void _applyConstraints() {
    edgeState.removeWhere((_, v) => v == -1);
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

  Future<void> applyBookmarkSubmit(List<List<int>> newSubmit) async {
    await removeHintLine();
    _undoStack.clear();
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
}
