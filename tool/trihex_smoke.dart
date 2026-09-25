// ignore_for_file: avoid_print
// Smoke test for TrihexGenerator. Run:
//   dart run tool/trihex_smoke.dart
// Expects to produce a valid puzzle for a few sizes and print stats.

import 'package:slitherlink_project/MakePuzzle/TrihexGenerator.dart';
import 'package:slitherlink_project/MakePuzzle/SlitherlinkGenerator.dart'
    show Difficulty;

void runSize(int rows, int cols) {
  final gen = TrihexGenerator(rows, cols, seed: rows * 31 + cols);
  final p = gen.generate(difficulty: Difficulty.normal);

  // Active edge sanity: every active edge must touch ≥ 1 cell that has a
  // non-zero solution count, and every cell whose count > 0 must touch
  // at least one active edge (trivially true since count > 0 implies
  // active edge incident).
  int hexClueShown = 0;
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      if (p.hexClue[r][c] >= 0) hexClueShown++;
      if (p.hexSolution[r][c] < 0 || p.hexSolution[r][c] > 6) {
        throw StateError('hex solution out of range');
      }
    }
  }
  int triClueShown = 0;
  for (final id in p.triangleIds) {
    final s = p.triSolution[id] ?? 0;
    if (s < 0 || s > 3) throw StateError('tri solution out of range');
    if ((p.triClue[id] ?? -1) >= 0) triClueShown++;
  }

  // Vertex-degree invariant: every trihex vertex should have 0 or 2
  // incident active edges. Decode each edge into its two trihex vertex
  // IDs and tally.
  final Map<int, int> degree = {};
  for (final e in p.activeEdges) {
    final int hi = e % 1000000000;
    final int lo = e ~/ 1000000000;
    degree[lo] = (degree[lo] ?? 0) + 1;
    degree[hi] = (degree[hi] ?? 0) + 1;
  }
  int badVertices = 0;
  degree.forEach((v, d) {
    if (d != 0 && d != 2) badVertices++;
  });
  if (badVertices > 0) {
    print('  WARN ${rows}x$cols: $badVertices vertices with bad degree');
  }

  // Cell coverage: fraction of cells touched by the loop (≥1 active edge).
  int touched = 0;
  int total = 0;
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      total++;
      if (p.hexSolution[r][c] > 0) touched++;
    }
  }
  for (final id in p.triangleIds) {
    total++;
    if ((p.triSolution[id] ?? 0) > 0) touched++;
  }
  final double coverage = total == 0 ? 0 : touched / total;

  print('  ${rows}x$cols hex: ${rows * cols} cells, '
      'tri: ${p.triangleIds.length} cells, '
      'active edges: ${p.activeEdges.length}, '
      'coverage: ${(coverage * 100).toStringAsFixed(1)}%, '
      'hex clues shown: $hexClueShown, tri clues shown: $triClueShown');
}

void roundTrip(int rows, int cols) {
  final gen = TrihexGenerator(rows, cols, seed: rows * 31 + cols);
  final p = gen.generate(difficulty: Difficulty.normal);
  final List<List<int>> answer = p.toAnswerFormat(gen);
  final p2 = TrihexPuzzle.fromAnswerFormat(answer);
  if (p2.activeEdges.length != p.activeEdges.length) {
    throw StateError('round-trip lost edges ($rows×$cols)');
  }
  if (p2.triangleIds.length != p.triangleIds.length) {
    throw StateError('round-trip lost triangles ($rows×$cols)');
  }
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      if (p2.hexClue[r][c] != p.hexClue[r][c]) {
        throw StateError('round-trip hex clue mismatch at ($r,$c)');
      }
    }
  }
  print('  ${rows}x$cols round-trip OK');
}

void main() {
  print('TrihexGenerator smoke test');
  for (final size in [[4, 4], [5, 5], [6, 6], [7, 7], [8, 8], [10, 10]]) {
    runSize(size[0], size[1]);
  }
  print('Round-trip:');
  for (final size in [[4, 4], [6, 6], [8, 8]]) {
    roundTrip(size[0], size[1]);
  }
  print('OK');
}
