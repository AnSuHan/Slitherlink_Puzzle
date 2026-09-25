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

/// Regression tests pinning the auto edge-disable (-1) behaviour, per shape,
/// through the REAL user input path (updateEdge / updateSquareBox).
///
/// Spec (docs/constraint_lookahead.md + project memory):
///   • CELL RULE: when the drawn edge count around a visible clue cell reaches
///     the clue number, every remaining undecided (0) edge of that cell must
///     become -1. (This is the regression the user reported: "drew enough but
///     the rest didn't auto-X".)
///   • VERTEX RULE: when two drawn edges meet at a vertex, every other
///     undecided edge at that vertex must become -1.
///   • INVARIANT: a user-drawn edge (value >= 1) is NEVER turned into -1.
///
/// All moves draw subsets of the generated ANSWER, so the board always stays
/// globally consistent — no revert guard can fire and the deductions are
/// mathematically sound.

List<List<int>> zerosLike(List<List<int>> grid) =>
    grid.map((r) => List<int>.filled(r.length, 0)).toList();

// ---------------------------------------------------------------------------
// Square canonical-grid helpers (layout identical to ReadSquare.readSubmit):
//   row 2*i   → horizontal edges of clue-row i (length cols)
//   row 2*i+1 → vertical edges of clue-row i (length cols + 1)
// ---------------------------------------------------------------------------

/// Cell (i, j) → its 4 canonical edges [up, down, left, right].
List<List<int>> squareCellEdges(int i, int j) => [
      [2 * i, j],
      [2 * i + 2, j],
      [2 * i + 1, j],
      [2 * i + 1, j + 1],
    ];

/// Vertex (vi, vj) → incident canonical edges.
List<List<int>> squareVertexEdges(int vi, int vj, int rows, int cols) {
  final List<List<int>> out = [];
  if (vj > 0) out.add([2 * vi, vj - 1]);
  if (vj < cols) out.add([2 * vi, vj]);
  if (vi > 0) out.add([2 * vi - 1, vj]);
  if (vi < rows) out.add([2 * vi + 1, vj]);
  return out;
}

/// Draw canonical edge (i, j) through the real user path. Mapping mirrors
/// SquareProvider._canonicalToPuzzle.
Future<void> drawCanonicalSquare(SquareProvider p, int i, int j) {
  if (i.isEven) {
    if (i == 0) return p.updateSquareBox(0, j, up: 1);
    return p.updateSquareBox(i ~/ 2 - 1, j, down: 1);
  }
  final int row = (i - 1) ~/ 2;
  if (j == 0) return p.updateSquareBox(row, 0, left: 1);
  return p.updateSquareBox(row, j - 1, right: 1);
}

// ---------------------------------------------------------------------------
// Triangle helpers (geometry ported from TriangleProvider._incidentEdges;
// vertices exist only at (vr + vi) odd).
// ---------------------------------------------------------------------------

int triGetEdge(TriangleProvider p, int r, int i, int e) {
  switch (e) {
    case 0:
      return p.puzzle[r][i].edge0;
    case 1:
      return p.puzzle[r][i].edge1;
    case 2:
      return p.puzzle[r][i].edge2;
  }
  return 0;
}

List<List<int>> triIncidentEdges(int vr, int vi, int rows, int triPerRow) {
  final List<List<int>> out = [];
  // 1. up-right
  if (vr >= 1) {
    if (vi < triPerRow) {
      out.add([vr - 1, vi, 1]);
    } else if (vi - 1 >= 0 && vi - 1 < triPerRow) {
      out.add([vr - 1, vi - 1, 2]);
    }
  }
  // 2. right horizontal
  if (vi + 2 <= triPerRow + 1) {
    if (vr < rows && vi < triPerRow) {
      out.add([vr, vi, 0]);
    } else if (vr >= 1 && vi < triPerRow) {
      out.add([vr - 1, vi, 0]);
    }
  }
  // 3. down-right
  if (vr < rows) {
    if (vi < triPerRow) {
      out.add([vr, vi, 1]);
    } else if (vi - 1 >= 0 && vi - 1 < triPerRow) {
      out.add([vr, vi - 1, 2]);
    }
  }
  // 4. down-left
  if (vr < rows && vi >= 1) {
    if (vi - 1 < triPerRow) {
      out.add([vr, vi - 1, 1]);
    } else if (vi - 2 >= 0 && vi - 2 < triPerRow) {
      out.add([vr, vi - 2, 2]);
    }
  }
  // 5. left horizontal
  if (vi >= 2) {
    if (vr < rows && vi - 2 < triPerRow) {
      out.add([vr, vi - 2, 0]);
    } else if (vr >= 1 && vi - 2 < triPerRow) {
      out.add([vr - 1, vi - 2, 0]);
    }
  }
  // 6. up-left
  if (vr >= 1 && vi >= 1) {
    if (vi - 1 < triPerRow) {
      out.add([vr - 1, vi - 1, 1]);
    } else if (vi - 2 >= 0 && vi - 2 < triPerRow) {
      out.add([vr - 1, vi - 2, 2]);
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Hexagon helpers (neighbour tables ported from HexagonProvider).
// ---------------------------------------------------------------------------

const List<List<int>> hexNbEven = [
  [-1, 0], [0, 1], [1, 0], [1, -1], [0, -1], [-1, -1],
];
const List<List<int>> hexNbOdd = [
  [-1, 1], [0, 1], [1, 1], [1, 0], [0, -1], [-1, 0],
];

List<int>? hexNeighborEdge(int rows, int cols, int r, int c, int e) {
  final d = (r & 1) == 0 ? hexNbEven[e] : hexNbOdd[e];
  final nr = r + d[0];
  final nc = c + d[1];
  if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) return null;
  return [nr, nc, (e + 3) % 6];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const timeout = Timeout(Duration(minutes: 3));

  // =========================================================================
  // CELL RULE — drawn count reaches clue → remaining undecided edges are -1.
  // =========================================================================

  testWidgets('Square: cell-rule auto-disable after drawing clue-count edges',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));

    await tester.runAsync(() async {
      int scenarios = 0;
      for (int seed = 1; seed <= 8 && scenarios < 3; seed++) {
        final gen = SlitherlinkGenerator(4, 4, seed: seed).generateSolution();
        final answer = gen.toEdgeFormat();
        final p = SquareProvider(context: ctx, loadKey: 'square_generate_4x4');
        p.setAnswer(answer);
        p.setSubmit(zerosLike(answer));
        await p.init();

        final int rows = p.puzzle.length;
        final int cols = p.puzzle[0].length;
        final init = await p.readSquare.readSubmit(p.puzzle);

        // Target: a visible clue 1..3 whose 4 edges are all still undecided.
        // Prefer clue >= 2 (multi-tap — the exact case the user reported).
        int ti = -1, tj = -1;
        for (final int minNum in [2, 1]) {
          outer:
          for (int i = 0; i < rows; i++) {
            for (int j = 0; j < cols; j++) {
              final int num = p.puzzle[i][j].num;
              if (num < minNum || num > 3) continue;
              final es = squareCellEdges(i, j);
              bool allZero = true;
              int ansCount = 0;
              for (final e in es) {
                if (init[e[0]][e[1]] != 0) allZero = false;
                if (answer[e[0]][e[1]] == 1) ansCount++;
              }
              if (allZero && ansCount == num) {
                ti = i;
                tj = j;
                break outer;
              }
            }
          }
          if (ti >= 0) break;
        }
        if (ti < 0) continue;
        debugPrint('Square cell-rule scenario: seed=$seed cell($ti,$tj) '
            'clue=${p.puzzle[ti][tj].num}');

        final es = squareCellEdges(ti, tj);
        final int num = p.puzzle[ti][tj].num;
        for (final e in es) {
          if (answer[e[0]][e[1]] == 1) {
            await drawCanonicalSquare(p, e[0], e[1]);
          }
        }

        final sub = p.submit;
        for (final e in es) {
          final int v = sub[e[0]][e[1]];
          if (answer[e[0]][e[1]] == 1) {
            expect(v, greaterThanOrEqualTo(1),
                reason: 'Square seed=$seed cell($ti,$tj) clue=$num: user-drawn '
                    'edge (${e[0]},${e[1]}) must stay drawn, got $v');
          } else {
            expect(v, -1,
                reason: 'Square seed=$seed cell($ti,$tj) clue=$num: after '
                    'drawing clue-count edges, remaining edge '
                    '(${e[0]},${e[1]}) must be auto-disabled (-1), got $v');
          }
        }
        scenarios++;
      }
      expect(scenarios, greaterThan(0),
          reason: 'no Square cell-rule scenario found across seeds — '
              'test setup issue');
    });
    await tester.pump(const Duration(milliseconds: 50));
  }, timeout: timeout);

  testWidgets('Triangle: cell-rule auto-disable after drawing clue-count edges',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));

    await tester.runAsync(() async {
      int scenarios = 0;
      for (int seed = 1; seed <= 8 && scenarios < 3; seed++) {
        final puzzle = TriangleGenerator(4, 4, seed: seed).generateSolution();
        final answer = puzzle.toEdgeFormat();
        final p =
            TriangleProvider(context: ctx, loadKey: 'triangle_generate_4x4');
        p.setAnswer(answer);
        p.setClue(puzzle.clue);
        p.setSubmit(zerosLike(answer));
        await p.init();

        int tr = -1, tix = -1;
        for (final int minNum in [2, 1]) {
          outer:
          for (int r = 0; r < p.rows; r++) {
            for (int i = 0; i < p.triPerRow; i++) {
              final int num = p.puzzle[r][i].num;
              if (num < minNum || num > 2) continue;
              bool allZero = true;
              int ansCount = 0;
              for (int e = 0; e < 3; e++) {
                if (triGetEdge(p, r, i, e) != 0) allZero = false;
                if (answer[r][i * 3 + e] == 1) ansCount++;
              }
              if (allZero && ansCount == num) {
                tr = r;
                tix = i;
                break outer;
              }
            }
          }
          if (tr >= 0) break;
        }
        if (tr < 0) continue;
        debugPrint('Triangle cell-rule scenario: seed=$seed cell($tr,$tix) '
            'clue=${p.puzzle[tr][tix].num}');

        final int num = p.puzzle[tr][tix].num;
        for (int e = 0; e < 3; e++) {
          if (answer[tr][tix * 3 + e] == 1) {
            await p.updateEdge(tr, tix, e, 1);
          }
        }

        for (int e = 0; e < 3; e++) {
          final int v = triGetEdge(p, tr, tix, e);
          if (answer[tr][tix * 3 + e] == 1) {
            expect(v, greaterThanOrEqualTo(1),
                reason: 'Triangle seed=$seed cell($tr,$tix) clue=$num: '
                    'user-drawn edge e$e must stay drawn, got $v');
          } else {
            expect(v, -1,
                reason: 'Triangle seed=$seed cell($tr,$tix) clue=$num: after '
                    'drawing clue-count edges, remaining edge e$e must be '
                    'auto-disabled (-1), got $v');
          }
        }
        scenarios++;
      }
      expect(scenarios, greaterThan(0),
          reason: 'no Triangle cell-rule scenario found across seeds');
    });
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }, timeout: timeout);

  testWidgets('Hexagon: cell-rule auto-disable after drawing clue-count edges',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));

    await tester.runAsync(() async {
      int scenarios = 0;
      for (int seed = 1; seed <= 8 && scenarios < 3; seed++) {
        final puzzle = HexagonGenerator(4, 4, seed: seed).generateSolution();
        final answer = puzzle.toEdgeFormat();
        final p =
            HexagonProvider(context: ctx, loadKey: 'hexagon_generate_4x4');
        p.setAnswer(answer);
        p.setDifficulty('normal');
        p.setSubmit(zerosLike(answer));
        await p.init();

        int trr = -1, tcc = -1;
        for (final int minNum in [2, 1]) {
          outer:
          for (int r = 0; r < p.rows; r++) {
            for (int c = 0; c < p.cols; c++) {
              final int num = p.puzzle[r][c].num;
              if (num < minNum || num > 5) continue;
              bool allZero = true;
              int ansCount = 0;
              for (int e = 0; e < 6; e++) {
                if (p.puzzle[r][c].edges[e] != 0) allZero = false;
                if (answer[r][c * 6 + e] == 1) ansCount++;
              }
              if (allZero && ansCount == num) {
                trr = r;
                tcc = c;
                break outer;
              }
            }
          }
          if (trr >= 0) break;
        }
        if (trr < 0) continue;
        debugPrint('Hexagon cell-rule scenario: seed=$seed cell($trr,$tcc) '
            'clue=${p.puzzle[trr][tcc].num}');

        final int num = p.puzzle[trr][tcc].num;
        for (int e = 0; e < 6; e++) {
          if (answer[trr][tcc * 6 + e] == 1) {
            await p.updateEdge(trr, tcc, e, 1);
          }
        }

        for (int e = 0; e < 6; e++) {
          final int v = p.puzzle[trr][tcc].edges[e];
          if (answer[trr][tcc * 6 + e] == 1) {
            expect(v, greaterThanOrEqualTo(1),
                reason: 'Hexagon seed=$seed cell($trr,$tcc) clue=$num: '
                    'user-drawn edge e$e must stay drawn, got $v');
          } else {
            expect(v, -1,
                reason: 'Hexagon seed=$seed cell($trr,$tcc) clue=$num: after '
                    'drawing clue-count edges, remaining edge e$e must be '
                    'auto-disabled (-1), got $v');
          }
        }
        scenarios++;
      }
      expect(scenarios, greaterThan(0),
          reason: 'no Hexagon cell-rule scenario found across seeds');
    });
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }, timeout: timeout);

  testWidgets('Trihex: cell-rule auto-disable after drawing clue-count edges',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));

    await tester.runAsync(() async {
      int scenarios = 0;
      for (int seed = 1; seed <= 8 && scenarios < 3; seed++) {
        final gen = TrihexGenerator(3, 3, seed: seed);
        final puzzle = gen.generateSolution();
        final answer = puzzle.toAnswerFormat(gen);
        final p = TrihexProvider(context: ctx, loadKey: 'trihex_generate_3x3');
        p.setAnswer(answer);
        p.setDifficulty('normal');
        p.setSubmit(zerosLike(answer));
        await p.init();

        // Target: visible hex clue 1..5 with all 6 perimeter edges undecided.
        // Prefer clue >= 2 (multi-tap — the exact case the user reported).
        List<int>? perim;
        int clue = -1, cr = -1, cc = -1;
        for (final int minNum in [2, 1]) {
          outer:
          for (int r = 0; r < p.rows; r++) {
            for (int c = 0; c < p.cols; c++) {
              final int num = p.puzzle.hexClue[r][c];
              if (num < minNum || num > 5) continue;
              final es = p.gen.hexCellEdgesOf(r, c);
              bool allZero = true;
              int ansCount = 0;
              for (final e in es) {
                if (p.edgeValue(e) != 0) allZero = false;
                if (p.puzzle.activeEdges.contains(e)) ansCount++;
              }
              if (allZero && ansCount == num) {
                perim = es;
                clue = num;
                cr = r;
                cc = c;
                break outer;
              }
            }
          }
          if (perim != null) break;
        }
        if (perim == null) continue;
        debugPrint(
            'Trihex cell-rule scenario: seed=$seed hex($cr,$cc) clue=$clue');

        for (final e in perim) {
          if (p.puzzle.activeEdges.contains(e)) {
            await p.updateEdge(e, 1);
          }
        }

        for (final e in perim) {
          final int v = p.edgeValue(e);
          if (p.puzzle.activeEdges.contains(e)) {
            expect(v, greaterThanOrEqualTo(1),
                reason: 'Trihex seed=$seed hex($cr,$cc) clue=$clue: '
                    'user-drawn edge $e must stay drawn, got $v');
          } else {
            expect(v, -1,
                reason: 'Trihex seed=$seed hex($cr,$cc) clue=$clue: after '
                    'drawing clue-count edges, remaining edge $e must be '
                    'auto-disabled (-1), got $v');
          }
        }
        scenarios++;
      }
      expect(scenarios, greaterThan(0),
          reason: 'no Trihex cell-rule scenario found across seeds');
    });
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }, timeout: timeout);

  // =========================================================================
  // VERTEX RULE — two drawn edges meet at a vertex → other undecided edges
  // at that vertex become -1.
  // =========================================================================

  testWidgets('Square: vertex-rule auto-disable when two drawn edges meet',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));

    await tester.runAsync(() async {
      int scenarios = 0;
      for (int seed = 1; seed <= 8 && scenarios < 3; seed++) {
        final gen = SlitherlinkGenerator(4, 4, seed: seed).generateSolution();
        final answer = gen.toEdgeFormat();
        final p = SquareProvider(context: ctx, loadKey: 'square_generate_4x4');
        p.setAnswer(answer);
        p.setSubmit(zerosLike(answer));
        await p.init();

        final int rows = p.puzzle.length;
        final int cols = p.puzzle[0].length;
        final init = await p.readSquare.readSubmit(p.puzzle);

        List<List<int>>? vEdges;
        outer:
        for (int vi = 0; vi <= rows; vi++) {
          for (int vj = 0; vj <= cols; vj++) {
            final es = squareVertexEdges(vi, vj, rows, cols);
            if (es.length < 3) continue;
            int ansCount = 0;
            bool allZero = true;
            for (final e in es) {
              if (init[e[0]][e[1]] != 0) allZero = false;
              if (answer[e[0]][e[1]] == 1) ansCount++;
            }
            if (allZero && ansCount == 2) {
              vEdges = es;
              break outer;
            }
          }
        }
        if (vEdges == null) continue;

        for (final e in vEdges) {
          if (answer[e[0]][e[1]] == 1) {
            await drawCanonicalSquare(p, e[0], e[1]);
          }
        }

        final sub = p.submit;
        for (final e in vEdges) {
          final int v = sub[e[0]][e[1]];
          if (answer[e[0]][e[1]] == 1) {
            expect(v, greaterThanOrEqualTo(1),
                reason: 'Square seed=$seed: user-drawn vertex edge '
                    '(${e[0]},${e[1]}) must stay drawn, got $v');
          } else {
            expect(v, -1,
                reason: 'Square seed=$seed: third edge (${e[0]},${e[1]}) at a '
                    'degree-2 vertex must be auto-disabled (-1), got $v');
          }
        }
        scenarios++;
      }
      expect(scenarios, greaterThan(0),
          reason: 'no Square vertex-rule scenario found across seeds');
    });
    await tester.pump(const Duration(milliseconds: 50));
  }, timeout: timeout);

  testWidgets('Triangle: vertex-rule auto-disable when two drawn edges meet',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));

    await tester.runAsync(() async {
      int scenarios = 0;
      for (int seed = 1; seed <= 8 && scenarios < 3; seed++) {
        final puzzle = TriangleGenerator(4, 4, seed: seed).generateSolution();
        final answer = puzzle.toEdgeFormat();
        final p =
            TriangleProvider(context: ctx, loadKey: 'triangle_generate_4x4');
        p.setAnswer(answer);
        p.setClue(puzzle.clue);
        p.setSubmit(zerosLike(answer));
        await p.init();

        List<List<int>>? vEdges;
        outer:
        for (int vr = 0; vr <= p.rows; vr++) {
          for (int vi = 0; vi <= p.triPerRow + 1; vi++) {
            if ((vr + vi).isEven) continue;
            final es = triIncidentEdges(vr, vi, p.rows, p.triPerRow);
            if (es.length < 3) continue;
            int ansCount = 0;
            bool allZero = true;
            for (final e in es) {
              if (triGetEdge(p, e[0], e[1], e[2]) != 0) allZero = false;
              if (answer[e[0]][e[1] * 3 + e[2]] == 1) ansCount++;
            }
            if (allZero && ansCount == 2) {
              vEdges = es;
              break outer;
            }
          }
        }
        if (vEdges == null) continue;

        for (final e in vEdges) {
          if (answer[e[0]][e[1] * 3 + e[2]] == 1) {
            await p.updateEdge(e[0], e[1], e[2], 1);
          }
        }

        for (final e in vEdges) {
          final int v = triGetEdge(p, e[0], e[1], e[2]);
          if (answer[e[0]][e[1] * 3 + e[2]] == 1) {
            expect(v, greaterThanOrEqualTo(1),
                reason: 'Triangle seed=$seed: user-drawn vertex edge '
                    '(${e[0]},${e[1]},e${e[2]}) must stay drawn, got $v');
          } else {
            expect(v, -1,
                reason: 'Triangle seed=$seed: other edge '
                    '(${e[0]},${e[1]},e${e[2]}) at a degree-2 vertex must be '
                    'auto-disabled (-1), got $v');
          }
        }
        scenarios++;
      }
      expect(scenarios, greaterThan(0),
          reason: 'no Triangle vertex-rule scenario found across seeds');
    });
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }, timeout: timeout);

  testWidgets('Hexagon: vertex-rule auto-disable when two drawn edges meet',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));

    await tester.runAsync(() async {
      int scenarios = 0;
      for (int seed = 1; seed <= 8 && scenarios < 3; seed++) {
        final puzzle = HexagonGenerator(4, 4, seed: seed).generateSolution();
        final answer = puzzle.toEdgeFormat();
        final p =
            HexagonProvider(context: ctx, loadKey: 'hexagon_generate_4x4');
        p.setAnswer(answer);
        p.setDifficulty('normal');
        p.setSubmit(zerosLike(answer));
        await p.init();

        // Find a cell whose consecutive answer edges e, e+1 share a vertex,
        // with the third vertex edge (shared by the two neighbour cells)
        // in-grid, non-answer, and undecided.
        int tr = -1, tc = -1, te = -1;
        List<int>? third;
        outer:
        for (int r = 0; r < p.rows; r++) {
          for (int c = 0; c < p.cols; c++) {
            for (int e = 0; e < 6; e++) {
              final int e2 = (e + 1) % 6;
              if (answer[r][c * 6 + e] != 1) continue;
              if (answer[r][c * 6 + e2] != 1) continue;
              final nbA = hexNeighborEdge(p.rows, p.cols, r, c, e);
              final nbB = hexNeighborEdge(p.rows, p.cols, r, c, e2);
              if (nbA == null || nbB == null) continue;
              // Third edge = the edge nbA shares with nbB.
              int k = -1;
              for (int cand = 0; cand < 6; cand++) {
                final nn =
                    hexNeighborEdge(p.rows, p.cols, nbA[0], nbA[1], cand);
                if (nn != null && nn[0] == nbB[0] && nn[1] == nbB[1]) {
                  k = cand;
                  break;
                }
              }
              if (k < 0) continue;
              if (answer[nbA[0]][nbA[1] * 6 + k] != 0) continue;
              if (p.puzzle[r][c].edges[e] != 0) continue;
              if (p.puzzle[r][c].edges[e2] != 0) continue;
              if (p.puzzle[nbA[0]][nbA[1]].edges[k] != 0) continue;
              tr = r;
              tc = c;
              te = e;
              third = [nbA[0], nbA[1], k];
              break outer;
            }
          }
        }
        if (third == null) continue;

        await p.updateEdge(tr, tc, te, 1);
        await p.updateEdge(tr, tc, (te + 1) % 6, 1);

        expect(p.puzzle[tr][tc].edges[te], greaterThanOrEqualTo(1),
            reason: 'Hexagon seed=$seed: drawn edge ($tr,$tc,e$te) must stay');
        expect(p.puzzle[tr][tc].edges[(te + 1) % 6], greaterThanOrEqualTo(1),
            reason:
                'Hexagon seed=$seed: drawn edge ($tr,$tc,e${(te + 1) % 6}) '
                'must stay');
        final int v = p.puzzle[third[0]][third[1]].edges[third[2]];
        expect(v, -1,
            reason: 'Hexagon seed=$seed: third edge '
                '(${third[0]},${third[1]},e${third[2]}) at the shared vertex '
                'must be auto-disabled (-1), got $v');
        scenarios++;
      }
      expect(scenarios, greaterThan(0),
          reason: 'no Hexagon vertex-rule scenario found across seeds');
    });
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }, timeout: timeout);

  testWidgets('Trihex: vertex-rule auto-disable when two drawn edges meet',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));

    await tester.runAsync(() async {
      int scenarios = 0;
      for (int seed = 1; seed <= 8 && scenarios < 3; seed++) {
        final gen = TrihexGenerator(3, 3, seed: seed);
        final puzzle = gen.generateSolution();
        final answer = puzzle.toAnswerFormat(gen);
        final p = TrihexProvider(context: ctx, loadKey: 'trihex_generate_3x3');
        p.setAnswer(answer);
        p.setDifficulty('normal');
        p.setSubmit(zerosLike(answer));
        await p.init();

        // Build vertex → incident edges from the edge-ID encoding
        // (id = lo * 1e9 + hi where lo/hi are the endpoint vertex ids).
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
        final Map<int, Set<int>> byVertex = {};
        for (final e in all) {
          final int hi = e % 1000000000;
          final int lo = e ~/ 1000000000;
          byVertex.putIfAbsent(lo, () => {}).add(e);
          byVertex.putIfAbsent(hi, () => {}).add(e);
        }

        Set<int>? vEdges;
        for (final entry in byVertex.entries) {
          final es = entry.value;
          if (es.length < 3) continue;
          int ansCount = 0;
          bool allZero = true;
          for (final e in es) {
            if (p.edgeValue(e) != 0) allZero = false;
            if (p.puzzle.activeEdges.contains(e)) ansCount++;
          }
          if (allZero && ansCount == 2) {
            vEdges = es;
            break;
          }
        }
        if (vEdges == null) continue;

        for (final e in vEdges) {
          if (p.puzzle.activeEdges.contains(e)) {
            await p.updateEdge(e, 1);
          }
        }

        for (final e in vEdges) {
          final int v = p.edgeValue(e);
          if (p.puzzle.activeEdges.contains(e)) {
            expect(v, greaterThanOrEqualTo(1),
                reason: 'Trihex seed=$seed: user-drawn vertex edge $e must '
                    'stay drawn, got $v');
          } else {
            expect(v, -1,
                reason: 'Trihex seed=$seed: other edge $e at a degree-2 '
                    'vertex must be auto-disabled (-1), got $v');
          }
        }
        scenarios++;
      }
      expect(scenarios, greaterThan(0),
          reason: 'no Trihex vertex-rule scenario found across seeds');
    });
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }, timeout: timeout);
}
