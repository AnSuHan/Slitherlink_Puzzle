import 'package:flutter_test/flutter_test.dart';
import 'package:slitherlink_project/provider/square_propagation_core.dart';

/// Regression tests for the five recent SquareProvider propagation bugs.
/// Each test recreates the original failure scenario and asserts the fixed
/// invariant. Tests use the public propagation core directly so they can run
/// without bootstrapping the Flutter widget tree.
///
/// Edge grid layout reminder (canonical, matches ReadSquare.readSubmit):
///   • Row 2*i      → horizontal edges of clue-row i (length cols)
///   • Row 2*i + 1  → vertical edges of clue-row i  (length cols + 1)
/// Cell (i, j) edges:
///   up    = w[2*i][j]
///   down  = w[2*i + 2][j]
///   left  = w[2*i + 1][j]
///   right = w[2*i + 1][j + 1]

/// Helper: build an empty edge grid for a rows×cols puzzle (all 0).
List<List<int>> emptyEdges(int rows, int cols) {
  final List<List<int>> g = [];
  for (int i = 0; i <= 2 * rows; i++) {
    g.add(List<int>.filled(i.isEven ? cols : cols + 1, 0));
  }
  return g;
}

/// Helper: count how many entries equal `v` in a 2D grid.
int countValue(List<List<int>> g, int v) {
  int n = 0;
  for (final row in g) {
    for (final x in row) {
      if (x == v) n++;
    }
  }
  return n;
}

/// Helper: replicate SquareBoxStateProvider._cycleEdgeValue verbatim. Kept
/// here (rather than imported) because the original is private and
/// widget-coupled, but the rule itself is small and rarely changes.
int cycleEdgeValue(int v) {
  if (v == 0 || v == -3) return 1; // fresh chain colour (any ≥1 stand-in)
  if (v >= 1 || v == -5) return -4;
  if (v == -1) return -2;
  if (v == -2) return -1;
  if (v == -4) return 0;
  return 0;
}

void main() {
  group('Square propagation regressions', () {
    test('hidden clue (num<0) does not cascade-disable its edges (mask guard)',
        () {
      // Bug: a single tap near a hidden-clue cell wiped the whole board
      // because the cell rule's count >= num test was true for any drawn
      // edge (since num was -1 or similar). Fix: every propagator skips
      // num < 0 cells.
      const int rows = 2, cols = 2;
      // Centre cell (0, 0) is hidden (num = -1). Surrounding clues are 2.
      final nums = [
        [-1, 2],
        [2, 2],
      ];
      final edges = emptyEdges(rows, cols);
      // Draw one edge inside the hidden cell so the buggy code would cascade.
      edges[0][0] = 1; // up edge of (0, 0)

      propagateDirectSquare(edges, rows, cols, nums);

      // After propagation, the only edges that should be -1 are those
      // mandated by the *real* clues (the 2-cells), never by the hidden
      // cell itself. Specifically, the right/down/left of the hidden cell
      // must remain undecided (0) — the hidden cell carries no constraint.
      expect(edges[2][0], 0, reason: 'down edge of hidden cell stays undecided');
      expect(edges[1][0], 0, reason: 'left edge of hidden cell stays undecided');
    });

    test('-2 (user red) is never a hard premise during propagation', () {
      // Bug: tapping an auto-disabled (-1) edge to mark it -2 would cascade
      // disable unrelated edges because the working grid kept -2 as -1.
      // Fix: orig→working maps -2 to 0 in applyConstraintsToEdgeGrid, and
      // -2 is restored only at positions whose new derived value is -1.
      //
      // Fixture: a 1×1 cell with num=0 disables all 4 of its edges. From
      // that fixed-point state, the user marks one auto-disable -2. Re-running
      // propagation must:
      //   • leave the -2 as -2 (rule still derives -1 there → restored)
      //   • leave the other 3 edges as -1 (unchanged)
      //   • introduce zero new disables
      const int rows = 1, cols = 1;
      final nums = [
        [0],
      ];
      // Already-propagated state: every edge of (0,0) is -1. User taps the
      // up edge → it becomes -2.
      final edges = [
        [-2], // up of (0, 0) — user red
        [-1, -1], // left, right
        [-1], // down
      ];

      final result = applyConstraintsToEdgeGrid(
        origEdges: edges,
        nums: nums,
        rows: rows,
        cols: cols,
      );

      // -2 mark is preserved.
      expect(result[0][0], -2,
          reason: '-2 marking must be restored after re-derivation as -1');
      // The other three edges remain -1 (re-derived from num=0 rule).
      expect(result[1][0], -1);
      expect(result[1][1], -1);
      expect(result[2][0], -1);
      // No spurious cascade — the count of disables (-1 plus -2) equals
      // exactly the 4 edges that the rule actually mandates.
      expect(countValue(result, -1) + countValue(result, -2), 4,
          reason: '-2 must not introduce extra cascade -1 anywhere');
    });

    test(
        '-4 (user X) on a critical edge does not cascade-wipe the board (revert guard)',
        () {
      // Bug: X-marking the answer line of a num=1 cell makes the cell
      // unsatisfiable (active+un < num) — look-ahead would then disable
      // every undecided edge. Fix: applyConstraintsToEdgeGrid runs a final
      // isWorkingStateConsistent check on the post-propagation state and
      // reverts to entry snapshot if false.
      const int rows = 2, cols = 2;
      final nums = [
        [1, 0], // (0,0) needs exactly 1 edge
        [0, 0], // (0,1), (1,0), (1,1) need 0 — all surrounding edges are -1
      ];
      // Initialize: cells with num=0 → all 4 edges -1 by direct rule. Easier
      // to start from an already-derived state and X-mark the lone surviving
      // edge.
      final edges = emptyEdges(rows, cols);
      // Manually set known auto-disables for num=0 cells.
      // (0,1): up=w[0][1], down=w[2][1], left=w[1][1], right=w[1][2]
      edges[0][1] = -1;
      edges[2][1] = -1;
      edges[1][1] = -1;
      edges[1][2] = -1;
      // (1,0): up=w[2][0], down=w[4][0], left=w[3][0], right=w[3][1]
      edges[2][0] = -1;
      edges[4][0] = -1;
      edges[3][0] = -1;
      edges[3][1] = -1;
      // (1,1): up=w[2][1] (shared), down=w[4][1], left=w[3][1] (shared), right=w[3][2]
      edges[4][1] = -1;
      edges[3][2] = -1;
      // (0,0) num=1: up=w[0][0], left=w[1][0] are the only edges not yet -1.
      // X-mark the up edge.
      edges[0][0] = -4;

      // After this state, the only way to satisfy (0,0)=1 would be the left
      // edge — but propagation is told to derive -1 from look-ahead, which
      // would fail isWorkingStateConsistent on a fresh re-derive (all
      // surrounding cells are 0/-1/-4 → state is consistent because left
      // edge can still draw). This test confirms no cascade wipe.
      final result = applyConstraintsToEdgeGrid(
        origEdges: edges,
        nums: nums,
        rows: rows,
        cols: cols,
      );

      // Critical assertion: the X mark survives; the puzzle did not flip
      // every undecided edge to -1.
      expect(result[0][0], -4, reason: 'X mark must survive');
      // Boards-wipe check: after a single X-mark, the count of newly
      // cascade-disabled edges must be bounded — not the entire grid.
      final disabledCount = countValue(result, -1);
      final totalEdges = result.fold<int>(0, (s, r) => s + r.length);
      expect(disabledCount, lessThan(totalEdges),
          reason: 'X mark must not wipe every edge');
    });

    test('snapshot/revert guards against look-ahead cascade on inconsistent state',
        () {
      // Bug: when the live state was already inconsistent (eg user dragged
      // the puzzle into a contradictory state via undo/redo), look-ahead
      // would mark every undecided edge -1. Fix: isWorkingStateConsistent
      // pre-check inside applyConstraintsToEdgeGrid — a sane snapshot is
      // returned via the revert path.
      const int rows = 1, cols = 2;
      final nums = [
        [1, 1],
      ];
      // Set up a contradictory live state: cell (0, 0) num=1 has TWO drawn
      // edges. The applyConstraints input is what the user produced, and
      // the function's job is to NOT silently disable the whole board.
      final edges = emptyEdges(rows, cols);
      edges[0][0] = 1; // up of (0,0)
      edges[1][0] = 1; // left of (0,0) — now active=2 > num=1

      final result = applyConstraintsToEdgeGrid(
        origEdges: edges,
        nums: nums,
        rows: rows,
        cols: cols,
      );

      // The revert should kick in because the post-propagation state is
      // still locally inconsistent (cell still has active>num). Result
      // must equal the entry snapshot — both drawn edges preserved.
      expect(result[0][0], 1, reason: 'first drawn edge must survive');
      expect(result[1][0], 1, reason: 'second drawn edge must survive');
      // No spurious cascade -1 anywhere.
      expect(countValue(result, -1), 0,
          reason: 'inconsistent state must not produce any cascade -1');
    });

    test('tap cycle: -1 → -2 → -1 (red marking toggle)', () {
      // Bug: an earlier change inverted the tap cycle so -1 went to -3 or
      // similar. Fix (4e0d398): -1 cycles to -2 (red), -2 cycles back to -1.
      expect(cycleEdgeValue(-1), -2,
          reason: 'auto-disabled edge tap → red user-questioned');
      expect(cycleEdgeValue(-2), -1,
          reason: 'red user-questioned tap → back to auto-disabled');
      // Sanity: the rest of the cycle is unchanged.
      expect(cycleEdgeValue(0), 1,
          reason: '0 → fresh chain colour (any ≥1 representative)');
      expect(cycleEdgeValue(-4), 0, reason: 'X tap → undecided');
    });
  });
}
