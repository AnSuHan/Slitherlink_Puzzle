import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:slitherlink_project/provider/square_propagation_core.dart';
import 'package:slitherlink_project/MakePuzzle/SlitherlinkGenerator.dart';

/// End-to-end completion test for the answer-oracle solver.
///
/// SquareProvider.solveHumanLike is heavily coupled to the widget tree
/// (updateSquareBox / setLineColorBox / ReadSquare), so it can't be driven
/// headlessly. This test instead reproduces the solver's *move-selection
/// logic* — the part that actually changed in the oracle rewrite — at the
/// canonical edge-grid level, using the SAME components the app uses:
///   • boards come from the real [SlitherlinkGenerator] (the app's generator),
///   • each step uses the real [square_propagation_core] functions.
///
/// The loop mirrors solveHumanLike (SquareProvider.dart ~L2100-2207):
///   1. forced-draw  (findForcedDrawByContradiction) — applied only if it
///      agrees with the answer,
///   2. forced-disable (findForcedDisableByContradiction) — applied only if
///      the answer leaves that edge undrawn,
///   3. otherwise the answer oracle draws the next un-drawn answer edge.
///
/// The guarantee under test: from an empty board, this loop always reaches the
/// full answer as a single closed loop, never trips an inconsistency, and never
/// draws an edge the answer doesn't contain — i.e. it can never end stuck or
/// wrong. That is exactly the property the user asked us to confirm.

/// Cell clues derived from the answer: the count of drawn answer edges around
/// each cell (canonical layout — see square_propagation_regression_test.dart).
List<List<int>> cluesFromAnswer(List<List<int>> answer, int rows, int cols) {
  return List.generate(
      rows,
      (r) => List.generate(cols, (c) {
            final int up = answer[2 * r][c];
            final int down = answer[2 * r + 2][c];
            final int left = answer[2 * r + 1][c];
            final int right = answer[2 * r + 1][c + 1];
            return (up == 1 ? 1 : 0) +
                (down == 1 ? 1 : 0) +
                (left == 1 ? 1 : 0) +
                (right == 1 ? 1 : 0);
          }));
}

/// Hide a deterministic subset of clues, mirroring
/// SquareProvider._maskByDifficulty (ratio = fraction *kept*; the rest become
/// -1, which every propagator skips). Pushes the solver onto the oracle more.
void maskClues(List<List<int>> nums, int rows, int cols,
    {required double ratioKept, required int seed}) {
  final cells = <List<int>>[];
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      cells.add([r, c]);
    }
  }
  cells.shuffle(Random(seed));
  final int keep = (cells.length * ratioKept).round();
  for (int i = keep; i < cells.length; i++) {
    nums[cells[i][0]][cells[i][1]] = -1;
  }
}

/// Run the oracle-solver simulation. Returns null on full success, otherwise a
/// human-readable failure reason.
String? simulateOracleSolve(List<List<int>> answer, List<List<int>> nums) {
  final int rows = answer.length ~/ 2;
  final int cols = answer[0].length;

  // Live edge grid (canonical layout), all undecided to start.
  final List<List<int>> edges =
      answer.map((row) => List<int>.filled(row.length, 0)).toList();

  int totalEdges = 0;
  for (final row in answer) {
    totalEdges += row.length;
  }
  final int maxIter = totalEdges * 4 + 100;

  bool answerDrawn(int i, int j) => answer[i][j] == 1;

  bool isSolved() {
    for (int i = 0; i < answer.length; i++) {
      for (int j = 0; j < answer[i].length; j++) {
        final bool ansSel = answer[i][j] == 1;
        final bool subSel = edges[i][j] > 0;
        if (ansSel != subSel) return false;
      }
    }
    final w = buildWorkingFromEdges(edges);
    return isSingleClosedLoop(w, rows, cols);
  }

  List<int>? nextOracle() {
    for (int i = 0; i < answer.length; i++) {
      for (int j = 0; j < answer[i].length; j++) {
        if (answer[i][j] == 1 && edges[i][j] <= 0) return [i, j];
      }
    }
    return null;
  }

  for (int iter = 0; iter < maxIter; iter++) {
    if (isSolved()) return null;

    final w = buildWorkingFromEdges(edges);
    propagateDirectSquare(w, rows, cols, nums);

    // The oracle never diverges from the solution, so a partial state that is
    // a subset of the answer must stay consistent. If this ever fires, the
    // propagation core has produced a spurious contradiction — a real bug.
    if (!isWorkingStateConsistent(w, rows, cols, nums) ||
        hasInconsistentLoopTopology(w, rows, cols)) {
      return 'spurious inconsistency at iter $iter';
    }

    final draw = findForcedDrawByContradiction(w, rows, cols, nums);
    if (draw != null && answerDrawn(draw[0], draw[1])) {
      edges[draw[0]][draw[1]] = 1;
      continue;
    }

    final disable = findForcedDisableByContradiction(w, rows, cols, nums);
    if (disable != null && !answerDrawn(disable[0], disable[1])) {
      edges[disable[0]][disable[1]] = -4; // user-X, mirrors solver disable
      continue;
    }

    final oracle = nextOracle();
    if (oracle != null) {
      edges[oracle[0]][oracle[1]] = 1;
      continue;
    }

    // No move available but not solved — should be impossible with the oracle.
    return 'no move but unsolved at iter $iter';
  }
  return 'exceeded $maxIter iterations without solving';
}

void main() {
  group('Square answer-oracle solver always completes', () {
    // A spread of sizes; seeds make each board reproducible on failure.
    const sizes = [
      [4, 4],
      [5, 5],
      [6, 7],
      [8, 8],
    ];

    for (final size in sizes) {
      final int rows = size[0];
      final int cols = size[1];

      test('full clues — ${rows}x$cols, 15 random boards', () {
        for (int seed = 1; seed <= 15; seed++) {
          final puzzle =
              SlitherlinkGenerator(rows, cols, seed: seed).generateSolution();
          final answer = puzzle.toEdgeFormat();
          final nums = cluesFromAnswer(answer, rows, cols);

          final reason = simulateOracleSolve(answer, nums);
          expect(reason, isNull,
              reason: '${rows}x$cols seed=$seed (full clues): $reason');
        }
      });

      test('masked clues (normal 55% kept) — ${rows}x$cols, 15 boards', () {
        for (int seed = 1; seed <= 15; seed++) {
          final puzzle =
              SlitherlinkGenerator(rows, cols, seed: seed).generateSolution();
          final answer = puzzle.toEdgeFormat();
          final nums = cluesFromAnswer(answer, rows, cols);
          maskClues(nums, rows, cols, ratioKept: 0.55, seed: seed);

          final reason = simulateOracleSolve(answer, nums);
          expect(reason, isNull,
              reason: '${rows}x$cols seed=$seed (masked 55%): $reason');
        }
      });

      test('all clues hidden (pure oracle) — ${rows}x$cols, 10 boards', () {
        for (int seed = 1; seed <= 10; seed++) {
          final puzzle =
              SlitherlinkGenerator(rows, cols, seed: seed).generateSolution();
          final answer = puzzle.toEdgeFormat();
          // Every cell hidden → no forced inference at all; only the oracle
          // can drive the board to completion.
          final nums =
              List.generate(rows, (_) => List<int>.filled(cols, -1));

          final reason = simulateOracleSolve(answer, nums);
          expect(reason, isNull,
              reason: '${rows}x$cols seed=$seed (all hidden): $reason');
        }
      });
    }
  });
}
