import 'package:flutter_test/flutter_test.dart';
import 'package:slitherlink_project/provider/square_propagation_core.dart';

/// Unit tests for propagateColoringSquare (Inside/Outside parity coloring).
///
/// Edge grid layout (canonical, matches ReadSquare.readSubmit):
///   • Row 2*i      → horizontal edges of clue-row i (length cols)
///   • Row 2*i + 1  → vertical edges of clue-row i  (length cols + 1)

List<List<int>> emptyEdges(int rows, int cols) {
  final List<List<int>> g = [];
  for (int i = 0; i <= 2 * rows; i++) {
    g.add(List<int>.filled(i.isEven ? cols : cols + 1, 0));
  }
  return g;
}

/// nums: 모든 셀에 -1 (hidden clue, propagation 미적용). coloring 만 검증하고
/// 싶을 때 사용 — cell rule 이 mutation 을 일관성 위반으로 판정하지 않게.
List<List<int>> emptyNums(int rows, int cols) =>
    List<List<int>>.generate(rows, (_) => List<int>.filled(cols, -1));

int countValue(List<List<int>> g, int v) {
  int n = 0;
  for (final row in g) {
    for (final x in row) {
      if (x == v) n++;
    }
  }
  return n;
}

void main() {
  group('propagateColoringSquare basic correctness', () {
    test('empty board: no decided edges → no changes, no contradiction', () {
      final w = emptyEdges(3, 3);
      final changed = propagateColoringSquare(w, 3, 3, emptyNums(3, 3));
      expect(changed, isFalse);
      expect(countValue(w, 1), 0);
      expect(countValue(w, -1), 0);
    });

    test('single drawn boundary edge: forces remaining boundary edges drawn (cell ≠ outside)', () {
      final w = emptyEdges(2, 2);
      // Top edge of cell (0,0) drawn — cell(0,0) ≠ outside.
      w[0][0] = 1;
      final changed = propagateColoringSquare(w, 2, 2, emptyNums(2, 2));
      // cell(0,0) is "different color" from outside. Therefore the left edge of
      // cell(0,0) (also between outside and cell(0,0)) MUST be drawn.
      // This is the Slitherlink Inside/Outside rule: any cell different from
      // outside must have ALL its boundary edges drawn.
      expect(changed, isTrue);
      expect(w[1][0], 1, reason: 'left of cell(0,0) must be drawn (boundary with outside, different color)');
    });

    test('boundary 0-cell pattern: 4 disabled edges → cell forced same as outside, no new edges', () {
      // 2x2 board, cell (0,0) = 0 means all 4 edges around it disabled.
      // Coloring should infer: cell(0,0) same color as outside (already by all -1).
      // No NEW forced moves because adjacent cells still unknown.
      final w = emptyEdges(2, 2);
      w[0][0] = -1;   // top
      w[1][0] = -1;   // left
      w[1][1] = -1;   // right (between cell(0,0) and cell(0,1))
      w[2][0] = -1;   // bottom (between cell(0,0) and cell(1,0))
      final changed = propagateColoringSquare(w, 2, 2, emptyNums(2, 2));
      // All 4 edges already decided. Phase 2 finds no undecided edges with
      // both sides determined relative to each other (cell(0,1) and cell(1,0)
      // are now same color as outside via the -1 edges; cell(1,1) is still
      // isolated).
      // Wait — cell(0,1) ↔ outside via w[0][1]=undecided (top edge of cell(0,1)).
      //   But cell(0,1) is unioned with cell(0,0) via w[1][1]=-1 (same color).
      //   cell(0,0) is unioned with outside via w[0][0]/w[1][0]=-1.
      //   So cell(0,1) is determined same as outside.
      //   Then w[0][1] (cell(0,1) ↔ outside) must be -1 (same color = disabled).
      // Same for w[1][2] (cell(0,1) right edge): cell(0,1) ↔ cell(1,1)? No,
      //   w[1][2] is between cell(0,1) and outside (right boundary). Same as outside.
      //   Wait — w[1][2] for cols=2: vj=2 == cols → right is outside. left is cell(0,1).
      //   So cell(0,1) ↔ outside → required parity 0 → disabled.
      expect(changed, isTrue);
      // Concretely: w[0][1] (top of cell(0,1)) → -1, w[1][2] (right of cell(0,1)) → -1,
      //             w[2][0] (already -1), w[2][1] (bottom of cell(0,1)? no, between
      //             cell(0,1) and cell(1,1)) — cell(1,1) is isolated, unknown.
      // Also w[1][0] already -1. Other affected:
      //   - w[2][1] (bottom of cell(0,1)) — cell(0,1) ↔ cell(1,1). cell(1,1) not in union → no force.
      //   - w[3][0] (left of cell(1,0)) — outside ↔ cell(1,0). cell(1,0) is unioned with cell(0,0) via w[2][0]=-1, so cell(1,0) ↔ outside. Required parity 0 → disable.
      //   - w[3][1] (between cell(1,0) and cell(1,1)) — cell(1,1) not unioned. no force.
      //   - w[4][0] (bottom of cell(1,0)) — cell(1,0) ↔ outside → disable.
      // So at least 4 new -1 forced.
      expect(w[0][1], -1);  // top of cell(0,1)
      expect(w[1][2], -1);  // right of cell(0,1)
      expect(w[3][0], -1);  // left of cell(1,0)
      expect(w[4][0], -1);  // bottom of cell(1,0)
    });

    test('three-cell zigzag pattern: draw and disable forced consistently', () {
      // 2x2 board. Draw w[0][0]=1 (top of cell(0,0)) and w[0][1]=1 (top of cell(0,1)).
      // outside ↔ cell(0,0) parity 1.
      // outside ↔ cell(0,1) parity 1.
      // → cell(0,0) and cell(0,1) same color (both opposite of outside).
      // → w[1][1] (between them) must be -1 (same color).
      final w = emptyEdges(2, 2);
      w[0][0] = 1;
      w[0][1] = 1;
      final changed = propagateColoringSquare(w, 2, 2, emptyNums(2, 2));
      expect(changed, isTrue);
      expect(w[1][1], -1);  // between cell(0,0) and cell(0,1)
    });

    test('contradiction: triangle of edges produces parity conflict', () {
      // 1x2 board, draw all 3 boundary edges of cell(0,0): top, left, right.
      // outside ↔ cell(0,0) via top: parity 1.
      // outside ↔ cell(0,0) via left: parity 1. (consistent)
      // outside ↔ cell(0,0) via right: parity 1 — but right is between cell(0,0) and cell(0,1).
      //   So that says cell(0,0) ↔ cell(0,1) parity 1.
      // No contradiction yet.
      // Add: draw bottom of cell(0,0) (= top of "row 1" outside). But 1x2 has rows=1, so w[2][0] is outside ↔ cell(0,0) parity 1.
      // All 4 edges of cell(0,0) drawn ↔ outside parity 1. Consistent.
      final w = emptyEdges(1, 2);
      w[0][0] = 1;
      w[1][0] = 1;
      w[1][1] = 1;
      w[2][0] = 1;
      final result = propagateColoringSquare(w, 1, 2, emptyNums(1, 2));
      // No contradiction (all consistent: outside ↔ cell(0,0) parity 1).
      // Phase 2: w[0][1] (top of cell(0,1)) — outside ↔ cell(0,1).
      //   cell(0,1) ↔ cell(0,0) parity 1 (via w[1][1]=1). cell(0,0) ↔ outside parity 1.
      //   So cell(0,1) ↔ outside parity 0 → w[0][1] = -1.
      // w[2][1] (bottom of cell(0,1)) — same → -1.
      // w[1][2] (right of cell(0,1)) — outside ↔ cell(0,1) parity 0 → -1.
      expect(result, isTrue);
      expect(w[0][1], -1);
      expect(w[2][1], -1);
      expect(w[1][2], -1);
    });

    test('genuine coloring contradiction: triangle of parities', () {
      // Construct a scenario where coloring should detect contradiction.
      // 2x2 board. Force union triangle a ↔ b parity 1, b ↔ c parity 1, c ↔ a parity 1.
      // Use: outside ↔ cell(0,0) drawn (parity 1), cell(0,0) ↔ cell(0,1) drawn (parity 1),
      //      outside ↔ cell(0,1) drawn (parity 1). But cell(0,0) ↔ cell(0,1) parity 1 implies
      //      outside ↔ cell(0,1) parity 0 (via outside ↔ cell(0,0) parity 1 XOR cell(0,0) ↔ cell(0,1) parity 1 = 0).
      //      Setting outside ↔ cell(0,1) parity 1 contradicts.
      final w = emptyEdges(2, 2);
      w[0][0] = 1;   // outside ↔ cell(0,0) parity 1
      w[1][1] = 1;   // cell(0,0) ↔ cell(0,1) parity 1
      w[0][1] = 1;   // outside ↔ cell(0,1) parity 1 — should contradict
      final result = propagateColoringSquare(w, 2, 2, emptyNums(2, 2));
      expect(result, isFalse);   // false = contradiction detected
    });
  });

  group('propagateColoringSquare path-compression stress', () {
    test('long chain of -1 disables: all cells in same color as outside, no false forced edges', () {
      // 1x10 board. Disable all top edges (cells all same as outside).
      // Phase 1 unions all cells with outside via top edges. parity all 0.
      // Phase 2 should force: all bottom edges -1, all interior left/right -1, etc.
      final w = emptyEdges(1, 10);
      for (int j = 0; j < 10; j++) {
        w[0][j] = -1;
      }
      final changed = propagateColoringSquare(w, 1, 10, emptyNums(1, 10));
      expect(changed, isTrue);
      // All bottom edges should now be -1 (each cell ↔ outside via bottom too).
      for (int j = 0; j < 10; j++) {
        expect(w[2][j], -1, reason: 'bottom edge of cell(0,$j) should be -1');
      }
      // All vertical edges should be -1 (between cells same color, between cell and outside same color).
      for (int j = 0; j <= 10; j++) {
        expect(w[1][j], -1, reason: 'vertical edge at col $j should be -1');
      }
    });

    test('long chain of +1 draws across cells: parity propagates correctly', () {
      // 1x4 board. Draw all top edges. All cells become "inside" (parity 1 vs outside).
      // Phase 2: w[1][1], w[1][2], w[1][3] (between adjacent cells) should be -1 (same color).
      // w[1][0] (left of cell(0,0)): outside ↔ cell(0,0), parity 1 → drawn.
      // w[1][4] (right of cell(0,3)): same → drawn.
      // w[2][j] for j=0..3: outside ↔ cell(0,j), parity 1 → drawn.
      final w = emptyEdges(1, 4);
      for (int j = 0; j < 4; j++) {
        w[0][j] = 1;
      }
      final changed = propagateColoringSquare(w, 1, 4, emptyNums(1, 4));
      expect(changed, isTrue);
      // Interior verticals same color, should be disabled
      expect(w[1][1], -1);
      expect(w[1][2], -1);
      expect(w[1][3], -1);
      // Boundary verticals + bottom edges should be drawn (cell color ≠ outside color)
      expect(w[1][0], 1);
      expect(w[1][4], 1);
      for (int j = 0; j < 4; j++) {
        expect(w[2][j], 1, reason: 'bottom of cell(0,$j) should be drawn');
      }
    });
  });
}
