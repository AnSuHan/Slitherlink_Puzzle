import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:slitherlink_project/provider/square_propagation_core.dart';
import 'package:slitherlink_project/MakePuzzle/SlitherlinkGenerator.dart';

/// Answer-free solver test.
///
/// Unlike square_solver_completion_test.dart (which drives the *oracle* loop and
/// feeds the answer in at every step), this exercises [solveSquareFromClues] /
/// [verifySquareFromClues] — the pure DFS that only ever sees the visible clues.
/// The answer is used solely by the test, to (a) derive the clues the player
/// would see and (b) check the solver re-derived the same loop on its own.

/// Cell clues derived from the answer: drawn-edge count around each cell
/// (canonical layout).
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

/// The working grid the answer represents (1 drawn / -1 not).
List<List<int>> answerAsWorking(List<List<int>> answer) =>
    answer.map((row) => row.map((v) => v == 1 ? 1 : -1).toList()).toList();

/// Mask clues like the app's difficulty masking: keep [ratioKept] of cells,
/// hide the rest (set to -1, which every propagator skips).
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

void main() {
  const sizes = [
    [4, 4],
    [5, 5],
    [6, 7],
    [8, 8],
  ];

  group('solveSquareFromClues re-derives the loop without the answer', () {
    for (final size in sizes) {
      final int rows = size[0];
      final int cols = size[1];

      test('full clues — ${rows}x$cols, 15 boards', () {
        for (int seed = 1; seed <= 15; seed++) {
          final puzzle =
              SlitherlinkGenerator(rows, cols, seed: seed).generateSolution();
          final answer = puzzle.toEdgeFormat();
          final nums = cluesFromAnswer(answer, rows, cols);

          final solution = solveSquareFromClues(nums, rows, cols);
          expect(solution, isNotNull,
              reason: '${rows}x$cols seed=$seed: no solution found');
          expect(solution, equals(answerAsWorking(answer)),
              reason: '${rows}x$cols seed=$seed: solver found a different loop');
        }
      });
    }
  });

  group('full-clue boards are uniquely solvable', () {
    for (final size in sizes) {
      final int rows = size[0];
      final int cols = size[1];

      test('${rows}x$cols, 15 boards', () {
        for (int seed = 1; seed <= 15; seed++) {
          final puzzle =
              SlitherlinkGenerator(rows, cols, seed: seed).generateSolution();
          final answer = puzzle.toEdgeFormat();
          final nums = cluesFromAnswer(answer, rows, cols);

          expect(verifySquareFromClues(nums, rows, cols),
              SquareVerifyResult.unique,
              reason: '${rows}x$cols seed=$seed: not uniquely solvable');
        }
      });
    }
  });

  group('logic-solvable implies unique (no-guess fairness check)', () {
    for (final size in sizes) {
      final int rows = size[0];
      final int cols = size[1];

      test('${rows}x$cols full + masked, 15 boards each', () {
        for (int seed = 1; seed <= 15; seed++) {
          final puzzle =
              SlitherlinkGenerator(rows, cols, seed: seed).generateSolution();
          final answer = puzzle.toEdgeFormat();

          // Full clues.
          final full = cluesFromAnswer(answer, rows, cols);
          if (isSquareLogicSolvable(full, rows, cols)) {
            expect(verifySquareFromClues(full, rows, cols),
                SquareVerifyResult.unique,
                reason: '${rows}x$cols seed=$seed full: logic-solvable but not unique');
          }

          // Masked clues.
          final masked = cluesFromAnswer(answer, rows, cols);
          maskClues(masked, rows, cols, ratioKept: 0.55, seed: seed);
          if (isSquareLogicSolvable(masked, rows, cols)) {
            expect(verifySquareFromClues(masked, rows, cols),
                SquareVerifyResult.unique,
                reason: '${rows}x$cols seed=$seed masked: logic-solvable but not unique');
            // And the unique solution must be the original answer.
            expect(solveSquareFromClues(masked, rows, cols),
                equals(answerAsWorking(answer)),
                reason: '${rows}x$cols seed=$seed masked: logic solution != answer');
          }
        }
      });
    }
  });

  group('masked (normal 55% kept) boards still solve to the same loop', () {
    for (final size in sizes) {
      final int rows = size[0];
      final int cols = size[1];

      test('${rows}x$cols, 15 boards', () {
        for (int seed = 1; seed <= 15; seed++) {
          final puzzle =
              SlitherlinkGenerator(rows, cols, seed: seed).generateSolution();
          final answer = puzzle.toEdgeFormat();
          final nums = cluesFromAnswer(answer, rows, cols);
          maskClues(nums, rows, cols, ratioKept: 0.55, seed: seed);

          // Masking may make the board ambiguous; if it stays unique the only
          // solution must be the original answer.
          final result = verifySquareFromClues(nums, rows, cols);
          expect(result == SquareVerifyResult.unique ||
                  result == SquareVerifyResult.multiple,
              isTrue,
              reason: '${rows}x$cols seed=$seed masked: $result');
          if (result == SquareVerifyResult.unique) {
            final solution = solveSquareFromClues(nums, rows, cols);
            expect(solution, equals(answerAsWorking(answer)),
                reason: '${rows}x$cols seed=$seed masked: diverged from answer');
          }
        }
      });
    }
  });
}
