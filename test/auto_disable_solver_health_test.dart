import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:slitherlink_project/MakePuzzle/SlitherlinkGenerator.dart';
import 'package:slitherlink_project/MakePuzzle/TriangleGenerator.dart';
import 'package:slitherlink_project/MakePuzzle/HexagonGenerator.dart';
import 'package:slitherlink_project/MakePuzzle/TrihexGenerator.dart';
import 'package:slitherlink_project/provider/TriangleProvider.dart';
import 'package:slitherlink_project/provider/HexagonProvider.dart';
import 'package:slitherlink_project/provider/TrihexProvider.dart';
import 'package:slitherlink_project/provider/square_propagation_core.dart';

/// Confirms the auto-solver stack still works alongside the auto-disable
/// behaviour changes: the answer-free DFS solver solves generated boards,
/// canAutoSolve accepts them, and the trihex tap cycle keeps the
/// -1 → -2 → -1 red-marking loop.

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

List<List<int>> zerosLike(List<List<int>> grid) =>
    grid.map((r) => List<int>.filled(r.length, 0)).toList();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const timeout = Timeout(Duration(minutes: 3));

  test('Square core solver: solveSquareFromClues finds a single closed loop',
      () {
    for (int seed = 1; seed <= 3; seed++) {
      final gen = SlitherlinkGenerator(4, 4, seed: seed).generateSolution();
      final answer = gen.toEdgeFormat();
      final nums = cluesFromAnswer(answer, 4, 4);

      final sol = solveSquareFromClues(nums, 4, 4,
          timeBudget: const Duration(seconds: 10));
      expect(sol, isNotNull,
          reason: 'Square seed=$seed: full-clue 4x4 board must be solvable');
      expect(isSingleClosedLoop(sol!, 4, 4), isTrue,
          reason: 'Square seed=$seed: solver output must be a single loop');

      expect(
          canAutoSolveSquareFromClues(nums, 4, 4,
              timeBudget: const Duration(seconds: 5)),
          isTrue,
          reason: 'Square seed=$seed: canAutoSolve must accept the board');
    }
  }, timeout: timeout);

  testWidgets('Triangle/Hexagon/Trihex: canAutoSolve accepts generated boards',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));

    await tester.runAsync(() async {
      for (int seed = 1; seed <= 2; seed++) {
        final puzzle = TriangleGenerator(4, 4, seed: seed).generateSolution();
        final answer = puzzle.toEdgeFormat();
        final p =
            TriangleProvider(context: ctx, loadKey: 'triangle_generate_4x4');
        p.setAnswer(answer);
        p.setClue(puzzle.clue);
        p.setSubmit(zerosLike(answer));
        await p.init();
        expect(await p.canAutoSolve(), isTrue,
            reason: 'Triangle seed=$seed: canAutoSolve must be true');
      }

      for (int seed = 1; seed <= 2; seed++) {
        final puzzle = HexagonGenerator(4, 4, seed: seed).generateSolution();
        final answer = puzzle.toEdgeFormat();
        final p =
            HexagonProvider(context: ctx, loadKey: 'hexagon_generate_4x4');
        p.setAnswer(answer);
        p.setDifficulty('normal');
        p.setSubmit(zerosLike(answer));
        await p.init();
        expect(await p.canAutoSolve(), isTrue,
            reason: 'Hexagon seed=$seed: canAutoSolve must be true');
      }

      for (int seed = 1; seed <= 2; seed++) {
        final gen = TrihexGenerator(3, 3, seed: seed);
        final puzzle = gen.generateSolution();
        final answer = puzzle.toAnswerFormat(gen);
        final p = TrihexProvider(context: ctx, loadKey: 'trihex_generate_3x3');
        p.setAnswer(answer);
        p.setDifficulty('normal');
        p.setSubmit(zerosLike(answer));
        await p.init();
        expect(await p.canAutoSolve(), isTrue,
            reason: 'Trihex seed=$seed: canAutoSolve must be true');
      }
    });
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }, timeout: timeout);

  test('Trihex tap cycle: -1 → -2 → -1 and 0 → colour → -4 → 0', () {
    final p = TrihexProvider(
        context: _FakeContext(), loadKey: 'trihex_generate_3x3');
    expect(p.cycleEdge(-1), -2,
        reason: 'auto-disabled edge tap → red user-questioned (-2)');
    expect(p.cycleEdge(-2), -1,
        reason: 'red user-questioned tap → back to auto-disabled (-1)');
    expect(p.cycleEdge(0), greaterThanOrEqualTo(1),
        reason: 'undecided tap → fresh chain colour');
    expect(p.cycleEdge(5), -4, reason: 'drawn tap → user X');
    expect(p.cycleEdge(-4), 0, reason: 'X tap → undecided');
  });
}

/// cycleEdge never touches context; a throwing stub keeps the constructor
/// honest without bootstrapping a widget tree.
class _FakeContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('BuildContext not available in this test');
}
