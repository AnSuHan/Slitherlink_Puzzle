import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:slitherlink_project/MakePuzzle/HexagonGenerator.dart';
import 'package:slitherlink_project/provider/HexagonProvider.dart';

/// DIAGNOSTIC: a freshly-loaded Hexagon puzzle must show NO drawn lines
/// (every edge value <= 0). If any edge is >= 1 after init, the solution is
/// being revealed on the first screen (the reported bug).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('fresh Hexagon board has no drawn (>=1) edges', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));

    await tester.runAsync(() async {
      for (int seed = 1; seed <= 5; seed++) {
        final puzzle = HexagonGenerator(4, 4, seed: seed).generateSolution();
        final answer = puzzle.toEdgeFormat();

        final p = HexagonProvider(
            context: ctx, loadKey: 'hexagon_generate_4x4');
        p.setAnswer(answer);
        p.setDifficulty('normal');
        p.setSubmit(answer.map((r) => List<int>.filled(r.length, 0)).toList());
        await p.init();

        int drawn = 0, disabled = 0, undecided = 0;
        final drawnPositions = <String>[];
        for (int r = 0; r < p.puzzle.length; r++) {
          for (int c = 0; c < p.puzzle[r].length; c++) {
            for (int e = 0; e < 6; e++) {
              final v = p.puzzle[r][c].edges[e];
              if (v >= 1) {
                drawn++;
                if (drawnPositions.length < 12) {
                  drawnPositions.add('($r,$c,$e)=$v');
                }
              } else if (v == -1) {
                disabled++;
              } else if (v == 0) {
                undecided++;
              }
            }
          }
        }
        // ignore: avoid_print
        print('seed=$seed drawn=$drawn disabled=$disabled undecided=$undecided '
            'sampleDrawn=$drawnPositions');
        expect(drawn, 0,
            reason: 'seed=$seed: $drawn edges drawn on fresh board '
                '(solution leaking). sample=$drawnPositions');
      }
    });
  });
}
