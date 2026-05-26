import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:slitherlink_project/MakePuzzle/TriangleGenerator.dart';
import 'package:slitherlink_project/MakePuzzle/HexagonGenerator.dart';
import 'package:slitherlink_project/MakePuzzle/TrihexGenerator.dart';
import 'package:slitherlink_project/provider/TriangleProvider.dart';
import 'package:slitherlink_project/provider/HexagonProvider.dart';
import 'package:slitherlink_project/provider/TrihexProvider.dart';

/// Completion test for the answer-oracle solver on the three non-square shapes.
///
/// Square's logic lives in a public propagation core, so its test
/// (square_solver_completion_test.dart) simulates the move-selection loop
/// directly. Triangle / Hexagon / Trihex keep that logic *private* inside the
/// provider, so here we drive the REAL [solveHumanLike] headlessly instead:
///
///   • a [MaterialApp] is pumped only to hand each provider a live
///     [BuildContext] — the solver path never touches `context` (only the
///     puzzle-complete dialog does, which the solver doesn't trigger),
///   • each board comes from the shape's real generator (the same one the app
///     uses), fed through setAnswer/setSubmit/init exactly like the scene does,
///   • [tester.runAsync] lets the solver's real `await` loop run to the end.
///
/// Assertion: every board ends at `solver_done` — the oracle guarantees the
/// solver always completes (never stuck / never labels-full / never wrong).

List<List<int>> zerosLike(List<List<int>> grid) =>
    grid.map((r) => List<int>.filled(r.length, 0)).toList();

void main() {
  // Each board is a full solve; keep sizes small and seed counts modest so the
  // suite stays fast while still covering many distinct boards.
  const int boardsPerShape = 8;
  const timeout = Timeout(Duration(minutes: 3));

  // The completion side-effect (showComplete) writes solved-count stats through
  // SharedPreferences and pushes a "complete" dialog. Mock prefs so the writes
  // succeed; a valid generate-style loadKey keeps UserInfo.incrementCompleted
  // from a RangeError when it splits the key. The dialog is flushed with
  // pumpAndSettle after each solve loop.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Triangle solveHumanLike always completes', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));

    await tester.runAsync(() async {
      for (int seed = 1; seed <= boardsPerShape; seed++) {
        final puzzle =
            TriangleGenerator(4, 4, seed: seed).generateSolution();
        final answer = puzzle.toEdgeFormat();

        final p = TriangleProvider(
            context: ctx, loadKey: 'triangle_generate_4x4');
        p.setAnswer(answer);
        p.setClue(puzzle.clue);
        p.setSubmit(zerosLike(answer));
        await p.init();

        await p.solveHumanLike();
        expect(p.solverStatus, 'solver_done',
            reason: 'Triangle 4x4 seed=$seed ended ${p.solverStatus}');
      }
    });
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
  }, timeout: timeout);

  testWidgets('Hexagon solveHumanLike always completes', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));

    await tester.runAsync(() async {
      for (int seed = 1; seed <= boardsPerShape; seed++) {
        final puzzle =
            HexagonGenerator(4, 4, seed: seed).generateSolution();
        final answer = puzzle.toEdgeFormat();

        final p = HexagonProvider(
            context: ctx, loadKey: 'hexagon_generate_4x4');
        p.setAnswer(answer);
        p.setDifficulty('normal');
        p.setSubmit(zerosLike(answer));
        await p.init();

        await p.solveHumanLike();
        expect(p.solverStatus, 'solver_done',
            reason: 'Hexagon 4x4 seed=$seed ended ${p.solverStatus}');
      }
    });
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
  }, timeout: timeout);

  testWidgets('Trihex solveHumanLike always completes', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));

    await tester.runAsync(() async {
      for (int seed = 1; seed <= boardsPerShape; seed++) {
        final gen = TrihexGenerator(3, 3, seed: seed);
        final puzzle = gen.generateSolution();
        final answer = puzzle.toAnswerFormat(gen);

        final p = TrihexProvider(
            context: ctx, loadKey: 'trihex_generate_3x3');
        p.setAnswer(answer);
        p.setDifficulty('normal');
        p.setSubmit(zerosLike(answer));
        await p.init();

        await p.solveHumanLike();
        expect(p.solverStatus, 'solver_done',
            reason: 'Trihex 3x3 seed=$seed ended ${p.solverStatus}');
      }
    });
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
  }, timeout: timeout);
}
