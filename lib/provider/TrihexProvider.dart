// ignore_for_file: file_names
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../MakePuzzle/TrihexGenerator.dart';
import '../Platform/ExtractData.dart'
  if (dart.library.html) '../Platform/ExtractDataWeb.dart';
import '../ThemeColor.dart';
import '../User/UserInfo.dart';
import '../l10n/app_localizations.dart';
import '../widgets/MainUI.dart';

/// Provider for the 3.6.3.6 trihexagonal puzzle. Step 2 keeps the API
/// minimal — rendering and tap propagation only. Cell rules, vertex
/// rules, chain colouring and undo/redo arrive in step 3.
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
  ///   0  = blank
  ///   1+ = drawn (colour token, matches Square/Hexagon line palette)
  ///   -1 = auto-disabled
  ///   -2 = manually marked wrong
  ///   -3 = hint highlight
  ///   -4 = X
  ///   -5 = wrong-hint flash
  final Map<int, int> edgeState = {};

  int rows = 0;
  int cols = 0;

  /// Difficulty for hint masking.
  String difficulty = "normal";

  void setAnswer(List<List<int>> answer) {
    puzzle = TrihexPuzzle.fromAnswerFormat(answer);
    rows = puzzle.rows;
    cols = puzzle.cols;
    gen = TrihexGenerator(rows, cols);
  }

  void setSubmit(List<List<int>> submit) {
    edgeState.clear();
    if (submit.isEmpty) return;
    // submit format: row 0 hex edges flat, row 1 tri edges flat.
    // Each int is the edge state for the matching perimeter slot.
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

    // Assemble cell descriptors: 0 = hex (r, c), 1 = tri (id).
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

  /// Step 2: plain edge update — no constraint propagation, no chain
  /// colouring. Step 3 will replace this with the full version.
  Future<void> updateEdge(int edgeId, int value) async {
    if (value == 0) {
      edgeState.remove(edgeId);
    } else {
      edgeState[edgeId] = value;
    }
    notifyListeners();
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
    final prefs = ExtractData();
    await prefs.saveDataToLocal(
      "${MainUI.getProgressKey()}_continue",
      jsonEncode(readSubmit()),
    );
  }

  // --- Stubs for step 3 ----------------------------------------------------

  Future<void> undo() async {}
  Future<void> redo() async {}
  Future<void> restart() async {
    edgeState.clear();
    notifyListeners();
  }

  Future<void> showHint(BuildContext context) async {
    for (final e in puzzle.activeEdges) {
      final v = edgeValue(e);
      if (v <= 0) {
        edgeState[e] = -3;
        notifyListeners();
        return;
      }
    }
  }

  Future<void> removeHintLine() async {
    edgeState.removeWhere((_, v) => v == -3 || v == -5);
    notifyListeners();
  }

  List<List<int>> snapshotSubmit() => readSubmit();

  Future<void> applyBookmarkSubmit(List<List<int>> newSubmit) async {
    await removeHintLine();
    setSubmit(newSubmit);
    notifyListeners();
  }

  /// Currently unused — placeholder so the scene can call it once the
  /// completion check arrives in step 3.
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
