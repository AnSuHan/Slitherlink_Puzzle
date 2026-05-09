// ignore_for_file: file_names
//
// Pure constraint-propagation logic for the Square board, extracted from
// SquareProvider so it can be exercised by unit tests without the rest of
// the Flutter widget tree.
//
// Working grid `w` convention (canonical edge layout, identical to the one
// produced by ReadSquare.readSubmit):
//   • Even rows (2*i)     → horizontal edges of clue-row i (length = cols)
//   • Odd rows (2*i + 1)  → vertical edges of clue-row i  (length = cols + 1)
// Cell (i, j) (0 ≤ i < rows, 0 ≤ j < cols) has 4 edges:
//   up    = w[2*i][j]
//   down  = w[2*i + 2][j]
//   left  = w[2*i + 1][j]
//   right = w[2*i + 1][j + 1]
// Edge values inside `w`:
//   1   = drawn
//   0   = undecided
//   -1  = disabled
// `nums[i][j]` is the clue at (i, j); a value < 0 marks a hidden clue and is
// skipped by every rule. See docs/constraint_lookahead.md for the full rule
// derivation; the helpers here implement Sections 2 and 3.

/// Direct-rule fixed-point propagation. Mutates `w` in place.
void propagateDirectSquare(
    List<List<int>> w, int rows, int cols, List<List<int>> nums) {
  bool changed = true;
  int iter = 0;
  while (changed && iter < 30) {
    changed = false;
    iter++;

    // Cell rule: count drawn vs. undecided around each clue cell. When the
    // drawn count reaches num, the remaining undecided edges become -1.
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        final int num = nums[i][j];
        if (num < 0 || num > 4) continue;
        final List<List<int>> es = [
          [2 * i, j], [2 * i + 2, j], [2 * i + 1, j], [2 * i + 1, j + 1],
        ];
        int dr = 0, un = 0;
        for (final e in es) {
          final int v = w[e[0]][e[1]];
          if (v == 1) {
            dr++;
          } else if (v == 0) {
            un++;
          }
        }
        if (un == 0) continue;
        if (dr == num) {
          for (final e in es) {
            if (w[e[0]][e[1]] == 0) {
              w[e[0]][e[1]] = -1;
              changed = true;
            }
          }
        }
      }
    }

    // Vertex rule: each grid vertex must end at degree 0 or 2. If two edges
    // are already drawn (degree-2 satisfied) any remaining undecided edge
    // becomes -1; if active==0 and only one undecided edge meets the vertex,
    // that lone undecided also becomes -1 (degree-1 is forbidden).
    for (int vi = 0; vi <= rows; vi++) {
      for (int vj = 0; vj <= cols; vj++) {
        final List<List<int>> ve = [];
        if (vj > 0) ve.add([2 * vi, vj - 1]);
        if (vj < cols) ve.add([2 * vi, vj]);
        if (vi > 0) ve.add([2 * vi - 1, vj]);
        if (vi < rows) ve.add([2 * vi + 1, vj]);
        int dr = 0, un = 0;
        for (final e in ve) {
          final int v = w[e[0]][e[1]];
          if (v == 1) {
            dr++;
          } else if (v == 0) {
            un++;
          }
        }
        if (un == 0) continue;
        if (dr >= 2) {
          for (final e in ve) {
            if (w[e[0]][e[1]] == 0) {
              w[e[0]][e[1]] = -1;
              changed = true;
            }
          }
        } else if (dr == 0 && un == 1) {
          for (final e in ve) {
            if (w[e[0]][e[1]] == 0) {
              w[e[0]][e[1]] = -1;
              changed = true;
            }
          }
        }
      }
    }
  }
}

/// Returns false iff the working grid already violates a hard constraint
/// (cell over-quota / starved, vertex degree > 2 or stuck-at-1). Look-ahead
/// must skip when this returns false — every hypothesis would be flagged
/// contradictory and disable every undecided edge.
bool isWorkingStateConsistent(
    List<List<int>> w, int rows, int cols, List<List<int>> nums) {
  for (int i = 0; i < rows; i++) {
    for (int j = 0; j < cols; j++) {
      final int num = nums[i][j];
      if (num < 0 || num > 4) continue;
      final List<List<int>> es = [
        [2 * i, j], [2 * i + 2, j], [2 * i + 1, j], [2 * i + 1, j + 1],
      ];
      int dr = 0, un = 0;
      for (final e in es) {
        final int v = w[e[0]][e[1]];
        if (v == 1) {
          dr++;
        } else if (v == 0) {
          un++;
        }
      }
      if (dr > num) return false;
      if (dr + un < num) return false;
    }
  }
  for (int vi = 0; vi <= rows; vi++) {
    for (int vj = 0; vj <= cols; vj++) {
      final List<List<int>> ve = [];
      if (vj > 0) ve.add([2 * vi, vj - 1]);
      if (vj < cols) ve.add([2 * vi, vj]);
      if (vi > 0) ve.add([2 * vi - 1, vj]);
      if (vi < rows) ve.add([2 * vi + 1, vj]);
      int dr = 0, un = 0;
      for (final e in ve) {
        final int v = w[e[0]][e[1]];
        if (v == 1) {
          dr++;
        } else if (v == 0) {
          un++;
        }
      }
      if (dr > 2) return false;
      if (dr == 1 && un == 0) return false;
    }
  }
  return true;
}

/// Hypothesis propagation. Caller assumes a single edge to be drawn (=1) and
/// then calls this to chase down consequences. Adds force-draw rules on top
/// of the direct-rule disables. Returns true on contradiction. Mutates `w`
/// freely; caller is responsible for snapshot/restore around this call.
bool propagateHypothesisSquare(
    List<List<int>> w, int rows, int cols, List<List<int>> nums) {
  bool changed = true;
  int iter = 0;
  while (changed && iter < 30) {
    changed = false;
    iter++;

    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        final int num = nums[i][j];
        if (num < 0 || num > 4) continue;
        final List<List<int>> es = [
          [2 * i, j], [2 * i + 2, j], [2 * i + 1, j], [2 * i + 1, j + 1],
        ];
        int dr = 0, un = 0;
        for (final e in es) {
          final int v = w[e[0]][e[1]];
          if (v == 1) {
            dr++;
          } else if (v == 0) {
            un++;
          }
        }
        if (dr > num) return true;
        if (dr + un < num) return true;
        if (dr == num && un > 0) {
          for (final e in es) {
            if (w[e[0]][e[1]] == 0) {
              w[e[0]][e[1]] = -1;
              changed = true;
            }
          }
        } else if (dr + un == num && un > 0) {
          for (final e in es) {
            if (w[e[0]][e[1]] == 0) {
              w[e[0]][e[1]] = 1;
              changed = true;
            }
          }
        }
      }
    }

    for (int vi = 0; vi <= rows; vi++) {
      for (int vj = 0; vj <= cols; vj++) {
        final List<List<int>> ve = [];
        if (vj > 0) ve.add([2 * vi, vj - 1]);
        if (vj < cols) ve.add([2 * vi, vj]);
        if (vi > 0) ve.add([2 * vi - 1, vj]);
        if (vi < rows) ve.add([2 * vi + 1, vj]);
        int dr = 0, un = 0;
        for (final e in ve) {
          final int v = w[e[0]][e[1]];
          if (v == 1) {
            dr++;
          } else if (v == 0) {
            un++;
          }
        }
        if (dr > 2) return true;
        if (dr == 1 && un == 0) return true;

        if (dr >= 2 && un > 0) {
          for (final e in ve) {
            if (w[e[0]][e[1]] == 0) {
              w[e[0]][e[1]] = -1;
              changed = true;
            }
          }
        } else if (dr == 0 && un > 0 && dr + un < 2) {
          for (final e in ve) {
            if (w[e[0]][e[1]] == 0) {
              w[e[0]][e[1]] = -1;
              changed = true;
            }
          }
        } else if (dr == 1 && un == 1) {
          for (final e in ve) {
            if (w[e[0]][e[1]] == 0) {
              w[e[0]][e[1]] = 1;
              changed = true;
            }
          }
        }
      }
    }
  }
  return false;
}

/// Orchestrates the full per-tap propagation cycle on a working grid built
/// from the live puzzle. Mirrors SquareProvider._applyConstraints (steps 2-7
/// of docs/constraint_lookahead.md §5) but operates on the canonical
/// edge-grid representation directly so it can be unit-tested.
///
/// Inputs:
///   • [origEdges]   live edge grid before propagation. Carries every per-
///                   edge mark seen by the user (≥1 drawn, 0 undecided,
///                   -1 auto-disabled, -2 user red, -3 hint, -4 user X,
///                   -5 wrong-hint).
///   • [nums]        clue numbers per cell (rows × cols). num < 0 → hidden.
///
/// Returns the new edge grid produced by one cycle: legacy -1/-2 are cleared
/// and re-derived from the current ≥1/-4 base; -2 is restored only at
/// positions whose new value is -1; if the result is globally infeasible
/// (cell starved, vertex stuck-at-1) the original [origEdges] is returned
/// unchanged so nothing cascades after a single-tap mistake.
List<List<int>> applyConstraintsToEdgeGrid({
  required List<List<int>> origEdges,
  required List<List<int>> nums,
  required int rows,
  required int cols,
}) {
  // Snapshot for cascade-abort revert.
  final List<List<int>> guardSnap =
      origEdges.map((r) => List<int>.from(r)).toList();

  // Build working grid: -2 maps to 0 (so it never acts as a hard premise).
  final List<List<int>> w = origEdges.map((row) => row.map((v) {
        if (v >= 1) return 1;
        if (v == 0 || v == -1 || v == -2) return 0;
        return -1; // -3 hint, -4 user X, -5 wrong-hint all hard-disabled
      }).toList()).toList();

  propagateDirectSquare(w, rows, cols, nums);

  if (isWorkingStateConsistent(w, rows, cols, nums)) {
    for (int laIter = 0; laIter < 5; laIter++) {
      bool laChanged = false;
      for (int er = 0; er < w.length; er++) {
        for (int ec = 0; ec < w[er].length; ec++) {
          if (w[er][ec] != 0) continue;
          final List<List<int>> snap =
              w.map((r) => List<int>.from(r)).toList();
          w[er][ec] = 1;
          final bool contradiction =
              propagateHypothesisSquare(w, rows, cols, nums);
          for (int rr = 0; rr < w.length; rr++) {
            for (int cc = 0; cc < w[rr].length; cc++) {
              w[rr][cc] = snap[rr][cc];
            }
          }
          if (contradiction) {
            w[er][ec] = -1;
            laChanged = true;
          }
        }
      }
      if (!laChanged) break;
      propagateDirectSquare(w, rows, cols, nums);
    }
  }

  // Apply propagation to the live edge grid; preserve user-locked marks
  // (≥1, -3, -4, -5). At positions originally -2, restore -2 only if the
  // new derived value is -1 (red marking referred to that very -1).
  final List<List<int>> result =
      origEdges.map((r) => List<int>.from(r)).toList();
  for (int i = 0; i < result.length; i++) {
    for (int j = 0; j < result[i].length; j++) {
      final int origValue = origEdges[i][j];
      if (origValue >= 1 ||
          origValue == -3 ||
          origValue == -4 ||
          origValue == -5) {
        continue;
      }
      final int derived = w[i][j] == -1 ? -1 : 0;
      result[i][j] = (origValue == -2 && derived == -1) ? -2 : derived;
    }
  }

  // Cascade-abort revert. If derived state violates a hard constraint
  // (e.g. user X-marks a critical line and look-ahead would otherwise wipe
  // the board), discard everything and return the entry snapshot.
  final List<List<int>> wForCheck = result.map((row) => row.map((v) {
        if (v >= 1) return 1;
        if (v == 0) return 0;
        return -1;
      }).toList()).toList();
  if (!isWorkingStateConsistent(wForCheck, rows, cols, nums)) {
    return guardSnap;
  }

  return result;
}
