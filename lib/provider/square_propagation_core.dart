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
///
/// If [changes] is provided, every position whose value is mutated from `0`
/// is appended to it as the encoded int `r * 1024 + c`. Caller can then
/// restore `w` cheaply by zeroing those positions instead of deep-copying
/// the whole grid before each call. This is the hot path for look-ahead — a
/// 10×10 board runs ~200 hypotheses per outer pass, so avoiding 200 deep
/// copies and the per-cell `[[r0,c0], [r1,c1], ...]` list allocations is a
/// major win (~1M allocations/propagation eliminated).
///
/// The inner loops are deliberately written without intermediate Lists:
/// every cell's 4 edges and every vertex's 2-4 incident edges are read by
/// direct indexing into `w`. Encoding `r * 1024 + c` assumes r, c < 1024
/// which holds for boards up to ~500 rows — far beyond any reasonable
/// puzzle size.
bool propagateHypothesisSquare(
    List<List<int>> w, int rows, int cols, List<List<int>> nums,
    {List<int>? changes}) {
  bool changed = true;
  int iter = 0;
  // 30 was a safety cap; in practice fixed-point converges in 2-5 iter.
  // Tightened to 12 to bound worst-case latency under rapid taps.
  while (changed && iter < 12) {
    changed = false;
    iter++;

    // Cell rule: each of the 4 edges around (i, j) is read directly.
    for (int i = 0; i < rows; i++) {
      final int r0 = 2 * i;       // up row
      final int r1 = r0 + 2;      // down row
      final int rm = r0 + 1;      // mid row (vertical edges)
      final List<int> wR0 = w[r0];
      final List<int> wR1 = w[r1];
      final List<int> wRm = w[rm];
      for (int j = 0; j < cols; j++) {
        final int num = nums[i][j];
        if (num < 0 || num > 4) continue;
        final int j1 = j + 1;
        final int v0 = wR0[j];     // up
        final int v1 = wR1[j];     // down
        final int v2 = wRm[j];     // left
        final int v3 = wRm[j1];    // right

        int dr = 0, un = 0;
        if (v0 == 1) {
          dr++;
        } else if (v0 == 0) un++;
        if (v1 == 1) {
          dr++;
        } else if (v1 == 0) un++;
        if (v2 == 1) {
          dr++;
        } else if (v2 == 0) un++;
        if (v3 == 1) {
          dr++;
        } else if (v3 == 0) un++;

        if (dr > num) return true;
        if (dr + un < num) return true;
        if (dr == num && un > 0) {
          if (v0 == 0) {
            if (changes != null) changes.add(r0 * 1024 + j);
            wR0[j] = -1;
            changed = true;
          }
          if (v1 == 0) {
            if (changes != null) changes.add(r1 * 1024 + j);
            wR1[j] = -1;
            changed = true;
          }
          if (v2 == 0) {
            if (changes != null) changes.add(rm * 1024 + j);
            wRm[j] = -1;
            changed = true;
          }
          if (v3 == 0) {
            if (changes != null) changes.add(rm * 1024 + j1);
            wRm[j1] = -1;
            changed = true;
          }
        } else if (dr + un == num && un > 0) {
          if (v0 == 0) {
            if (changes != null) changes.add(r0 * 1024 + j);
            wR0[j] = 1;
            changed = true;
          }
          if (v1 == 0) {
            if (changes != null) changes.add(r1 * 1024 + j);
            wR1[j] = 1;
            changed = true;
          }
          if (v2 == 0) {
            if (changes != null) changes.add(rm * 1024 + j);
            wRm[j] = 1;
            changed = true;
          }
          if (v3 == 0) {
            if (changes != null) changes.add(rm * 1024 + j1);
            wRm[j1] = 1;
            changed = true;
          }
        }
      }
    }

    // Vertex rule: each of the up to 4 incident edges is read with bound
    // checks inline. Sentinel value 99 stands in for "no edge here" and is
    // counted as neither drawn nor undecided.
    for (int vi = 0; vi <= rows; vi++) {
      final int rUp = 2 * vi - 1;
      final int rDn = 2 * vi + 1;
      final int rH = 2 * vi;
      final List<int>? wRUp = vi > 0 ? w[rUp] : null;
      final List<int>? wRDn = vi < rows ? w[rDn] : null;
      final List<int> wRH = w[rH];
      for (int vj = 0; vj <= cols; vj++) {
        final int vL = vj > 0 ? wRH[vj - 1] : 99;
        final int vR = vj < cols ? wRH[vj] : 99;
        final int vU = wRUp != null ? wRUp[vj] : 99;
        final int vD = wRDn != null ? wRDn[vj] : 99;

        int dr = 0, un = 0;
        if (vL == 1) {
          dr++;
        } else if (vL == 0) un++;
        if (vR == 1) {
          dr++;
        } else if (vR == 0) un++;
        if (vU == 1) {
          dr++;
        } else if (vU == 0) un++;
        if (vD == 1) {
          dr++;
        } else if (vD == 0) un++;

        if (dr > 2) return true;
        if (dr == 1 && un == 0) return true;

        // Decide which mutation rule applies.
        // 0 = none, -1 = disable undecideds, 1 = force-draw undecideds.
        int mutateTo = 0;
        if (dr >= 2 && un > 0) {
          mutateTo = -1;
        } else if (dr == 0 && un > 0 && dr + un < 2) {
          mutateTo = -1;
        } else if (dr == 1 && un == 1) {
          mutateTo = 1;
        }
        if (mutateTo == 0) continue;

        if (vL == 0) {
          final int c = vj - 1;
          if (changes != null) changes.add(rH * 1024 + c);
          wRH[c] = mutateTo;
          changed = true;
        }
        if (vR == 0) {
          if (changes != null) changes.add(rH * 1024 + vj);
          wRH[vj] = mutateTo;
          changed = true;
        }
        if (vU == 0) {
          if (changes != null) changes.add(rUp * 1024 + vj);
          wRUp![vj] = mutateTo;
          changed = true;
        }
        if (vD == 0) {
          if (changes != null) changes.add(rDn * 1024 + vj);
          wRDn![vj] = mutateTo;
          changed = true;
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

/// Build a working grid {1, 0, -1} from a live edge grid.
/// ≥1 → 1 (drawn), 0/-2 → 0 (undecided, -2 is user-red disagreeing with -1),
/// any other negative value (-1 auto-disable, -3/-5 hint, -4 user X) → -1.
List<List<int>> buildWorkingFromEdges(List<List<int>> edges) {
  return edges
      .map((row) => row.map((v) {
            if (v >= 1) return 1;
            if (v == 0 || v == -2) return 0;
            return -1;
          }).toList())
      .toList();
}

/// Solver-only complement to [propagateHypothesisSquare]: tests the
/// "edge = -1" hypothesis on every undecided position. If propagation reaches
/// a contradiction, the edge must in fact be drawn (=1). Returns the
/// canonical [row, col] of the first such forced-draw inference, or null if
/// none is found.
///
/// Caller MUST have already run [propagateDirectSquare] and verified
/// [isWorkingStateConsistent] on [w] — passing in an already-inconsistent
/// grid yields meaningless results (every hypothesis would be flagged as
/// contradiction).
///
/// Mirrors the snapshot-restore pattern used in the live-grid look-ahead
/// inside `SquareProvider._applyConstraints`: the seed mutation is appended
/// to [changes] manually so the restore loop zeros it together with the
/// hypothesis-propagated changes.
List<int>? findForcedDrawByContradiction(
    List<List<int>> w, int rows, int cols, List<List<int>> nums) {
  final List<int> hypChanges = <int>[];
  for (int er = 0; er < w.length; er++) {
    for (int ec = 0; ec < w[er].length; ec++) {
      if (w[er][ec] != 0) continue;
      hypChanges.clear();
      hypChanges.add(er * 1024 + ec);
      w[er][ec] = -1;
      final bool contradiction =
          propagateHypothesisSquare(w, rows, cols, nums, changes: hypChanges);
      for (final pos in hypChanges) {
        w[pos ~/ 1024][pos & 1023] = 0;
      }
      if (contradiction) {
        return [er, ec];
      }
    }
  }
  return null;
}

/// Solver-only complement: tests the "edge = +1" hypothesis on every
/// undecided position. If propagation contradicts, the edge must be -1
/// (cannot be drawn). Returns canonical [row, col] of the first such forced
/// -1 inference, or null.
///
/// `_applyConstraints` already runs this look-ahead inline, but bounded to
/// `for (laIter = 0; laIter < 2; ...)` outer iterations — deep deductions
/// escape into the live grid still undecided. Without this solver-side step,
/// such edges fall through to [pickHighestImpactGuess] and used to be
/// misclassified as "high-impact guess to draw" (see
/// docs/auto_solver_bug_analysis.md §1).
List<int>? findForcedDisableByContradiction(
    List<List<int>> w, int rows, int cols, List<List<int>> nums) {
  final List<int> hypChanges = <int>[];
  for (int er = 0; er < w.length; er++) {
    for (int ec = 0; ec < w[er].length; ec++) {
      if (w[er][ec] != 0) continue;
      hypChanges.clear();
      hypChanges.add(er * 1024 + ec);
      w[er][ec] = 1;
      final bool contradiction =
          propagateHypothesisSquare(w, rows, cols, nums, changes: hypChanges);
      for (final pos in hypChanges) {
        w[pos ~/ 1024][pos & 1023] = 0;
      }
      if (contradiction) {
        return [er, ec];
      }
    }
  }
  return null;
}

/// Pick the undecided edge whose hypothesis (=1) triggers the largest cascade
/// of forced inferences. Used by the human-like solver as a guess heuristic
/// when no 100% confirmed move exists — the edge that maximally constrains
/// the remaining state is the cheapest place to branch.
///
/// **Contradiction edges are excluded** (skipped, not promoted): a contradicting
/// hypothesis means the edge is forced -1, not a guess candidate. Callers must
/// run [findForcedDisableByContradiction] first to harvest those forced -1
/// inferences as locked X marks; otherwise drawing them as +1 introduces a
/// wrong premise the solver cannot recover from (docs/auto_solver_bug_analysis.md §1).
///
/// Returns null when no non-contradicting undecided edge remains (in that
/// case the solver should be calling [findForcedDisableByContradiction]
/// instead).
List<int>? pickHighestImpactGuess(
    List<List<int>> w, int rows, int cols, List<List<int>> nums) {
  int bestR = -1, bestC = -1, bestScore = -1;
  final List<int> hypChanges = <int>[];
  for (int er = 0; er < w.length; er++) {
    for (int ec = 0; ec < w[er].length; ec++) {
      if (w[er][ec] != 0) continue;
      hypChanges.clear();
      hypChanges.add(er * 1024 + ec);
      w[er][ec] = 1;
      final bool contradiction =
          propagateHypothesisSquare(w, rows, cols, nums, changes: hypChanges);
      final int score = hypChanges.length;
      for (final pos in hypChanges) {
        w[pos ~/ 1024][pos & 1023] = 0;
      }
      // contradiction edge 는 forced -1 이므로 guess 후보에서 제외.
      // 호출자는 findForcedDisableByContradiction 으로 먼저 잡아내야 함.
      if (contradiction) continue;
      if (score > bestScore) {
        bestScore = score;
        bestR = er;
        bestC = ec;
      }
    }
  }
  if (bestR < 0) return null;
  return [bestR, bestC];
}
