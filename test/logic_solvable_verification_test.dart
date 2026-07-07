import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:slitherlink_project/provider/square_propagation_core.dart';
import 'package:slitherlink_project/MakePuzzle/SlitherlinkGenerator.dart';
import 'package:slitherlink_project/MakePuzzle/TriangleGenerator.dart';
import 'package:slitherlink_project/MakePuzzle/HexagonGenerator.dart';
import 'package:slitherlink_project/MakePuzzle/TrihexGenerator.dart';
import 'package:slitherlink_project/provider/TriangleProvider.dart';
import 'package:slitherlink_project/provider/HexagonProvider.dart';
import 'package:slitherlink_project/provider/TrihexProvider.dart';

/// Measures the no-guess "fair puzzle" pass rate of [isLogicSolvable] across
/// freshly generated boards, and asserts the correctness invariant: a board
/// reported logic-solvable must actually be solvable by the auto-solver.
///
/// The pass rate tells us how aggressive the generate→verify→regenerate loop in
/// each scene must be (a low rate means many regenerations per board).

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

List<List<int>> zerosLike(List<List<int>> grid) =>
    grid.map((r) => List<int>.filled(r.length, 0)).toList();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Square logic-solvable pass rate (core, normal mask)', () {
    int pass = 0;
    const int n = 40;
    for (int seed = 1; seed <= n; seed++) {
      final puzzle = SlitherlinkGenerator(6, 6, seed: seed).generateSolution();
      final answer = puzzle.toEdgeFormat();
      final nums = cluesFromAnswer(answer, 6, 6);
      maskClues(nums, 6, 6, ratioKept: 0.55, seed: seed);
      if (isSquareLogicSolvable(nums, 6, 6)) pass++;
    }
    debugPrint('Square 6x6 normal-mask logic-solvable: $pass / $n');
    expect(pass, greaterThan(0));
  });

  testWidgets('Triangle/Hexagon/Trihex logic-solvable pass rate', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));

    await tester.runAsync(() async {
      int triPass = 0, hexPass = 0, triHexPass = 0;
      int triAuto = 0, hexAuto = 0;
      const int n = 20;

      for (int seed = 1; seed <= n; seed++) {
        final puzzle = TriangleGenerator(4, 4, seed: seed).generateSolution();
        final answer = puzzle.toEdgeFormat();
        final p = TriangleProvider(context: ctx, loadKey: 'triangle_generate_4x4');
        p.setAnswer(answer);
        p.setClue(puzzle.clue);
        p.setSubmit(zerosLike(answer));
        await p.init();
        if (p.isLogicSolvable()) triPass++;
        if (await p.canAutoSolve()) triAuto++;
      }
      debugPrint('Triangle 4x4 logic-solvable: $triPass / $n | canAutoSolve: $triAuto / $n');
      expect(triAuto, n, reason: 'Triangle: all generated boards must be auto-solvable');

      for (int seed = 1; seed <= n; seed++) {
        final puzzle = HexagonGenerator(4, 4, seed: seed).generateSolution();
        final answer = puzzle.toEdgeFormat();
        final p = HexagonProvider(context: ctx, loadKey: 'hexagon_generate_4x4');
        p.setAnswer(answer);
        p.setDifficulty('normal');
        p.setSubmit(zerosLike(answer));
        await p.init();
        if (p.isLogicSolvable()) hexPass++;
        if (await p.canAutoSolve()) hexAuto++;
      }
      debugPrint('Hexagon 4x4 logic-solvable: $hexPass / $n | canAutoSolve: $hexAuto / $n');
      expect(hexAuto, n, reason: 'Hexagon: all generated boards must be auto-solvable');

      for (final diff in ['easy', 'normal', 'hard']) {
        int dPass = 0;
        int dAuto = 0;
        for (int seed = 1; seed <= n; seed++) {
          final gen = TrihexGenerator(3, 3, seed: seed);
          final puzzle = gen.generateSolution();
          final answer = puzzle.toAnswerFormat(gen);
          final p = TrihexProvider(context: ctx, loadKey: 'trihex_generate_3x3');
          p.setAnswer(answer);
          p.setDifficulty(diff);
          p.setSubmit(zerosLike(answer));
          await p.init();
          if (p.isLogicSolvable()) dPass++;
          if (await p.canAutoSolve()) dAuto++;
        }
        debugPrint('Trihex 3x3 [$diff] logic-solvable: $dPass / $n | canAutoSolve: $dAuto / $n');
        if (diff == 'normal') {
          triHexPass = dPass;
          expect(dAuto, n, reason: 'Trihex normal: all generated boards must be auto-solvable');
        }
      }
    });
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
