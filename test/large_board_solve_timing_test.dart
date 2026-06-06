import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:slitherlink_project/MakePuzzle/TriangleGenerator.dart';
import 'package:slitherlink_project/MakePuzzle/HexagonGenerator.dart';
import 'package:slitherlink_project/provider/TriangleProvider.dart';
import 'package:slitherlink_project/provider/HexagonProvider.dart';

/// Large-board auto-solve timing guard. Before the _solverFastApply fix the
/// oracle path still ran three O(edges) hypothesis passes per move, so a big
/// Triangle/Hexagon board froze the UI thread for many seconds. These boards
/// must now finish well under the (generous) bound below.
List<List<int>> zerosLike(List<List<int>> grid) =>
    grid.map((r) => List<int>.filled(r.length, 0)).toList();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Triangle 10x10 auto-solve completes quickly', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));

    await tester.runAsync(() async {
      final puzzle = TriangleGenerator(10, 10, seed: 3).generateSolution();
      final answer = puzzle.toEdgeFormat();
      final p = TriangleProvider(context: ctx, loadKey: 'triangle_generate_10x10');
      p.setAnswer(answer);
      p.setClue(puzzle.clue);
      p.setSubmit(zerosLike(answer));
      await p.init();

      final sw = Stopwatch()..start();
      await p.solveHumanLike();
      sw.stop();
      debugPrint('Triangle 10x10 solve: ${sw.elapsedMilliseconds} ms');
      expect(p.solverStatus, 'solver_done');
      expect(sw.elapsedMilliseconds, lessThan(10000),
          reason: 'Triangle 10x10 took ${sw.elapsedMilliseconds} ms');
    });
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('Hexagon 10x10 auto-solve completes quickly', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));

    await tester.runAsync(() async {
      final puzzle = HexagonGenerator(10, 10, seed: 3).generateSolution();
      final answer = puzzle.toEdgeFormat();
      final p = HexagonProvider(context: ctx, loadKey: 'hexagon_generate_10x10');
      p.setAnswer(answer);
      p.setDifficulty('normal');
      p.setSubmit(zerosLike(answer));
      await p.init();

      final sw = Stopwatch()..start();
      await p.solveHumanLike();
      sw.stop();
      debugPrint('Hexagon 10x10 solve: ${sw.elapsedMilliseconds} ms');
      expect(p.solverStatus, 'solver_done');
      expect(sw.elapsedMilliseconds, lessThan(10000),
          reason: 'Hexagon 10x10 took ${sw.elapsedMilliseconds} ms');
    });
  }, timeout: const Timeout(Duration(minutes: 2)));
}
