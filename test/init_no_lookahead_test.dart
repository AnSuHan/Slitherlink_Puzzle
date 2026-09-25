import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:slitherlink_project/MakePuzzle/SlitherlinkGenerator.dart';
import 'package:slitherlink_project/MakePuzzle/TriangleGenerator.dart';
import 'package:slitherlink_project/MakePuzzle/HexagonGenerator.dart';
import 'package:slitherlink_project/MakePuzzle/TrihexGenerator.dart';
import 'package:slitherlink_project/provider/SquareProvider.dart';
import 'package:slitherlink_project/provider/TriangleProvider.dart';
import 'package:slitherlink_project/provider/HexagonProvider.dart';
import 'package:slitherlink_project/provider/TrihexProvider.dart';
import 'package:slitherlink_project/provider/square_propagation_core.dart';

/// Pins the TIMING rule of auto-disable deduction (project memory
/// `project_init_no_lookahead`):
///
///   1. At init (zero user input) only DIRECT rules may run — look-ahead
///      deductions must NOT appear, otherwise the answer skeleton is exposed
///      on the first screen.
///   2. After the user's first move, _applyConstraints runs direct rules AND
///      the 1-step look-ahead, so deeper deductions appear.
///
/// The "look-ahead only" deduction used below: a clue-1 cell whose two edges
/// meet at a degree-2 vertex. Drawing either edge forces the other (vertex
/// degree rule) which over-fills the clue → both edges are -1, but ONLY a
/// hypothesis test can see that. Direct rules alone leave them undecided.

List<List<int>> zerosLike(List<List<int>> grid) =>
    grid.map((r) => List<int>.filled(r.length, 0)).toList();

List<List<int>> emptyEdges(int rows, int cols) {
  final List<List<int>> g = [];
  for (int i = 0; i <= 2 * rows; i++) {
    g.add(List<int>.filled(i.isEven ? cols : cols + 1, 0));
  }
  return g;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const timeout = Timeout(Duration(minutes: 3));

  // =========================================================================
  // Look-ahead machinery sanity (Square core): the corner-1 pattern is
  // invisible to direct rules but must be caught by the look-ahead cycle.
  // =========================================================================

  test('Square core: corner-1 disable requires look-ahead, not direct rules',
      () {
    const int rows = 2, cols = 2;
    final nums = [
      [1, -1],
      [-1, -1],
    ];

    // Direct rules alone must NOT touch the corner edges (this is exactly
    // why init — which only runs direct rules — must not show them).
    final direct = emptyEdges(rows, cols);
    propagateDirectSquare(direct, rows, cols, nums);
    expect(direct[0][0], 0,
        reason: 'direct rules must not disable the corner-1 top edge');
    expect(direct[1][0], 0,
        reason: 'direct rules must not disable the corner-1 left edge');

    // The full per-tap cycle (direct + look-ahead) must disable both corner
    // edges of the 1-cell: drawing one forces the other via the degree-2
    // corner vertex and over-fills the clue.
    final result = applyConstraintsToEdgeGrid(
      origEdges: emptyEdges(rows, cols),
      nums: nums,
      rows: rows,
      cols: cols,
    );
    expect(result[0][0], -1,
        reason: 'look-ahead must disable the corner-1 top edge');
    expect(result[1][0], -1,
        reason: 'look-ahead must disable the corner-1 left edge');
  });

  // =========================================================================
  // Deterministic timing test (Triangle): look-ahead-only edges are 0 at
  // init and become -1 after the user's FIRST move.
  // =========================================================================

  testWidgets(
      'Triangle: look-ahead deduction absent at init, appears after first move',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));

    await tester.runAsync(() async {
      // Hand-built 1×(4 triangles) board. Triangle (0,0) is Up with clue 1;
      // its base (e0) and left diagonal (e1) meet at the board's bottom-left
      // vertex, which has exactly those two edges (degree 2). Drawing either
      // one forces the other → clue 1 over-filled → both are -1, but only
      // via look-ahead.
      final answer = [List<int>.filled(12, 0)]; // rows=1, cols=2
      final clue = [
        [1, -1, -1, -1]
      ];
      final p =
          TriangleProvider(context: ctx, loadKey: 'triangle_generate_1x2');
      p.setAnswer(answer);
      p.setClue(clue);
      p.setSubmit(zerosLike(answer));
      await p.init();

      // TIMING RULE 1: at init only direct rules ran — the look-ahead-only
      // edges must still be undecided (no solution spoiler on first screen).
      expect(p.puzzle[0][0].edge0, 0,
          reason: 'init must not run look-ahead: (0,0).e0 must stay 0');
      expect(p.puzzle[0][0].edge1, 0,
          reason: 'init must not run look-ahead: (0,0).e1 must stay 0');

      // First user move: draw an unrelated edge far from the clue cell.
      await p.updateEdge(0, 2, 0, 1);

      // TIMING RULE 2: after the first move _applyConstraints runs
      // direct + look-ahead → the corner-1 edges are now deduced -1.
      expect(p.puzzle[0][2].edge0, greaterThanOrEqualTo(1),
          reason: 'the user-drawn edge itself must stay drawn');
      expect(p.puzzle[0][0].edge0, -1,
          reason: 'after the first move look-ahead must disable (0,0).e0');
      expect(p.puzzle[0][0].edge1, -1,
          reason: 'after the first move look-ahead must disable (0,0).e1');
    });
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }, timeout: timeout);

  // =========================================================================
  // Generated boards: init must not reveal the solution. No edge may be
  // drawn (>= 1), and the -1 mask must not be so complete that the answer
  // skeleton is exposed (some non-answer edges must remain undecided).
  // =========================================================================

  testWidgets('Square: fresh board init shows clues only', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));

    await tester.runAsync(() async {
      for (int seed = 1; seed <= 5; seed++) {
        final gen = SlitherlinkGenerator(4, 4, seed: seed).generateSolution();
        final answer = gen.toEdgeFormat();
        final p = SquareProvider(context: ctx, loadKey: 'square_generate_4x4');
        p.setAnswer(answer);
        p.setSubmit(zerosLike(answer));
        await p.init();

        final init = await p.readSquare.readSubmit(p.puzzle);
        int drawn = 0, nonAnswerUndecided = 0, answerDisabled = 0;
        for (int i = 0; i < init.length; i++) {
          for (int j = 0; j < init[i].length; j++) {
            if (init[i][j] >= 1) drawn++;
            if (answer[i][j] != 1 && init[i][j] == 0) nonAnswerUndecided++;
            if (answer[i][j] == 1 && init[i][j] == -1) answerDisabled++;
          }
        }
        expect(drawn, 0,
            reason: 'Square seed=$seed: fresh board must have no drawn edges');
        expect(answerDisabled, 0,
            reason: 'Square seed=$seed: init must never disable a solution '
                'edge (direct rules are sound)');
        expect(nonAnswerUndecided, greaterThan(0),
            reason: 'Square seed=$seed: init disabled every non-answer edge '
                '— the answer skeleton is exposed (look-ahead ran at init)');
      }
    });
    await tester.pump(const Duration(milliseconds: 50));
  }, timeout: timeout);

  testWidgets('Triangle: fresh board init shows clues only', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));

    await tester.runAsync(() async {
      for (int seed = 1; seed <= 5; seed++) {
        final puzzle = TriangleGenerator(4, 4, seed: seed).generateSolution();
        final answer = puzzle.toEdgeFormat();
        final p =
            TriangleProvider(context: ctx, loadKey: 'triangle_generate_4x4');
        p.setAnswer(answer);
        p.setClue(puzzle.clue);
        p.setSubmit(zerosLike(answer));
        await p.init();

        int drawn = 0, nonAnswerUndecided = 0, answerDisabled = 0;
        for (int r = 0; r < p.rows; r++) {
          for (int i = 0; i < p.triPerRow; i++) {
            final vals = [
              p.puzzle[r][i].edge0,
              p.puzzle[r][i].edge1,
              p.puzzle[r][i].edge2,
            ];
            for (int e = 0; e < 3; e++) {
              final int ans = answer[r][i * 3 + e];
              if (vals[e] >= 1) drawn++;
              if (ans != 1 && vals[e] == 0) nonAnswerUndecided++;
              if (ans == 1 && vals[e] == -1) answerDisabled++;
            }
          }
        }
        expect(drawn, 0,
            reason:
                'Triangle seed=$seed: fresh board must have no drawn edges');
        expect(answerDisabled, 0,
            reason: 'Triangle seed=$seed: init must never disable a solution '
                'edge');
        expect(nonAnswerUndecided, greaterThan(0),
            reason: 'Triangle seed=$seed: init disabled every non-answer '
                'edge — answer skeleton exposed (look-ahead ran at init)');
      }
    });
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }, timeout: timeout);

  testWidgets('Hexagon: fresh board init shows clues only', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));

    await tester.runAsync(() async {
      for (int seed = 1; seed <= 5; seed++) {
        final puzzle = HexagonGenerator(4, 4, seed: seed).generateSolution();
        final answer = puzzle.toEdgeFormat();
        final p =
            HexagonProvider(context: ctx, loadKey: 'hexagon_generate_4x4');
        p.setAnswer(answer);
        p.setDifficulty('normal');
        p.setSubmit(zerosLike(answer));
        await p.init();

        int drawn = 0, nonAnswerUndecided = 0, answerDisabled = 0;
        for (int r = 0; r < p.rows; r++) {
          for (int c = 0; c < p.cols; c++) {
            for (int e = 0; e < 6; e++) {
              final int v = p.puzzle[r][c].edges[e];
              final int ans = answer[r][c * 6 + e];
              if (v >= 1) drawn++;
              if (ans != 1 && v == 0) nonAnswerUndecided++;
              if (ans == 1 && v == -1) answerDisabled++;
            }
          }
        }
        expect(drawn, 0,
            reason: 'Hexagon seed=$seed: fresh board must have no drawn edges');
        expect(answerDisabled, 0,
            reason:
                'Hexagon seed=$seed: init must never disable a solution edge');
        expect(nonAnswerUndecided, greaterThan(0),
            reason: 'Hexagon seed=$seed: init disabled every non-answer edge '
                '— answer skeleton exposed (look-ahead ran at init)');
      }
    });
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }, timeout: timeout);

  testWidgets('Trihex: fresh board init shows clues only', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));

    await tester.runAsync(() async {
      for (int seed = 1; seed <= 5; seed++) {
        final gen = TrihexGenerator(3, 3, seed: seed);
        final puzzle = gen.generateSolution();
        final answer = puzzle.toAnswerFormat(gen);
        final p = TrihexProvider(context: ctx, loadKey: 'trihex_generate_3x3');
        p.setAnswer(answer);
        p.setDifficulty('normal');
        p.setSubmit(zerosLike(answer));
        await p.init();

        // Collect every edge id in the grid.
        final Set<int> all = {};
        for (int r = 0; r < p.rows; r++) {
          for (int c = 0; c < p.cols; c++) {
            all.addAll(p.gen.hexCellEdgesOf(r, c));
          }
        }
        final tri = p.gen.enumerateTriangles();
        for (final id in p.puzzle.triangleIds) {
          final rep = tri.rep[id]!;
          all.addAll(p.gen.triangleEdgesOf(rep[0], rep[1], rep[2]));
        }

        int drawn = 0, nonAnswerUndecided = 0, answerDisabled = 0;
        for (final e in all) {
          final int v = p.edgeValue(e);
          final bool ans = p.puzzle.activeEdges.contains(e);
          if (v >= 1) drawn++;
          if (!ans && v == 0) nonAnswerUndecided++;
          if (ans && v == -1) answerDisabled++;
        }
        expect(drawn, 0,
            reason: 'Trihex seed=$seed: fresh board must have no drawn edges');
        expect(answerDisabled, 0,
            reason:
                'Trihex seed=$seed: init must never disable a solution edge');
        expect(nonAnswerUndecided, greaterThan(0),
            reason: 'Trihex seed=$seed: init disabled every non-answer edge '
                '— answer skeleton exposed (look-ahead ran at init)');
      }
    });
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }, timeout: timeout);
}
