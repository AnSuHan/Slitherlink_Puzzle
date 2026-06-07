import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:slitherlink_project/MakePuzzle/TriangleGenerator.dart';
import 'package:slitherlink_project/MakePuzzle/HexagonGenerator.dart';
import 'package:slitherlink_project/provider/TriangleProvider.dart';
import 'package:slitherlink_project/provider/HexagonProvider.dart';

/// A solved Slitherlink board is a single loop, so every drawn segment is
/// vertex-connected to the next. With color-chain merging in updateEdge the
/// whole loop must therefore end as ONE colour. Before the fix Triangle's
/// updateEdge stored the random per-edge colour verbatim (no merge), so a
/// solved board showed a patchwork of colours ("색이 이어지지 않아").
List<List<int>> zerosLike(List<List<int>> grid) =>
    grid.map((r) => List<int>.filled(r.length, 0)).toList();

Set<int> distinctPositiveColors(List<List<int>> submit) {
  final s = <int>{};
  for (final row in submit) {
    for (final v in row) {
      if (v >= 1) s.add(v);
    }
  }
  return s;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Triangle auto-solved loop is a single colour', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));

    await tester.runAsync(() async {
      for (int seed = 1; seed <= 6; seed++) {
        final puzzle = TriangleGenerator(4, 4, seed: seed).generateSolution();
        final answer = puzzle.toEdgeFormat();
        final p = TriangleProvider(context: ctx, loadKey: 'triangle_generate_4x4');
        p.setAnswer(answer);
        p.setClue(puzzle.clue);
        p.setSubmit(zerosLike(answer));
        await p.init();

        await p.solveHumanLike();
        expect(p.solverStatus, 'solver_done', reason: 'seed=$seed');
        final colors = distinctPositiveColors(p.submit);
        expect(colors.length, 1,
            reason: 'Triangle seed=$seed loop colours=$colors (expected 1)');
      }
    });
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('Hexagon auto-solved loop is a single colour', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));

    await tester.runAsync(() async {
      for (int seed = 1; seed <= 6; seed++) {
        final puzzle = HexagonGenerator(4, 4, seed: seed).generateSolution();
        final answer = puzzle.toEdgeFormat();
        final p = HexagonProvider(context: ctx, loadKey: 'hexagon_generate_4x4');
        p.setAnswer(answer);
        p.setDifficulty('normal');
        p.setSubmit(zerosLike(answer));
        await p.init();

        await p.solveHumanLike();
        expect(p.solverStatus, 'solver_done', reason: 'seed=$seed');
        final colors = distinctPositiveColors(p.submit);
        expect(colors.length, 1,
            reason: 'Hexagon seed=$seed loop colours=$colors (expected 1)');
      }
    });
  }, timeout: const Timeout(Duration(minutes: 2)));
}
