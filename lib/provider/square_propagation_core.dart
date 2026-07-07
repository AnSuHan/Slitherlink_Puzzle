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
///
/// [clickDerivedOnly] true 면 "사용자가 그은 변에서 파생되는 -1" 만 만든다
/// (2026-07-08 라이브 정책, docs/constraint_lookahead.md 상단 참조): 셀 num=0
/// 같은 단서-only 비활성과 꼭짓점 starvation 을 건너뛴다. 솔버(solveSquareFromClues
/// / applyConstraintsToEdgeGrid) 는 기본값 false 로 완전 추론을 유지해야 한다.
void propagateDirectSquare(
    List<List<int>> w, int rows, int cols, List<List<int>> nums,
    {bool clickDerivedOnly = false}) {
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
        // 클릭 파생만: 그은 변이 없으면(num=0 자동 비활성 등) 라이브에서 스킵.
        if (clickDerivedOnly && dr == 0) continue;
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
        } else if (!clickDerivedOnly && dr == 0 && un == 1) {
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

/// Slitherlink 의 Inside/Outside coloring 규칙 propagation.
/// 모든 셀과 "외부" 가상 노드를 weighted union-find 에 넣고, 결정된 edge 별로
/// 양쪽 노드의 parity 를 union (그어진 edge = different, disabled = same).
/// 이후 모든 미정 edge 에 대해 양쪽 노드의 parity 관계가 결정되어 있으면
/// 그 edge 도 forced (다른 색 = 그어야 함, 같은 색 = 비활성화).
///
/// 이 한 패스가 cell quota / vertex degree 규칙으론 안 풀리는 변의 대부분을
/// 즉시 결정해 분기 폭을 급격히 줄인다 — Slitherlink 솔버 문헌의 핵심 기법.
/// 16×11 hard 보드 기준 한 호출 비용 O(E + V·α(V)) ≈ ~1000 ops.
///
/// **방어 rollback**: Phase 2 가 마킹한 mutation 으로 셀 quota / 꼭짓점 차수
/// 가 깨지면 (예: 0-인접 1-셀의 모든 edge 가 disable 되어 cell rule 위반) 모든
/// mutation 을 rollback 하고 false 반환. coloring 이 (수학적으로 옳지만) puzzle
/// 의 다른 제약과 충돌하는 forced 를 만드는 경우 솔버를 더럽히지 않게 한다.
///
/// 반환: w 에 새로 마킹된 edge 가 있고 일관성이 유지되면 true. coloring 자체
/// union 단계에서 contradiction 이거나 mutation 으로 셀/꼭짓점 일관성이 깨지면
/// false 반환 (호출자는 false 면 그 round 의 coloring 효과는 없는 것으로 본다).
bool propagateColoringSquare(
    List<List<int>> w, int rows, int cols, List<List<int>> nums) {
  final int nCells = rows * cols;
  final int outsideIdx = nCells;
  final int nNodes = nCells + 1;

  final List<int> parent = List<int>.generate(nNodes, (i) => i);
  final List<int> rankArr = List<int>.filled(nNodes, 0);
  // parity[x] = relation to parent: 0=same color, 1=different color.
  final List<int> parity = List<int>.filled(nNodes, 0);

  // find: 경로 압축. (root, parityFromXToRoot) 반환.
  // 1) 경로를 모으며 root 도달. 2) 경로 끝(root 와 직접 연결된 노드)부터 거꾸로
  // 압축해 parity 누적값을 정확히 갱신. 재귀 대신 반복 (큰 보드 stack 안전).
  final List<int> pathBuf = [];
  List<int> findInfo(int x) {
    pathBuf.clear();
    int cur = x;
    while (parent[cur] != cur) {
      pathBuf.add(cur);
      cur = parent[cur];
    }
    final int root = cur;
    // 압축: path[len-1] 은 이미 parent==root, parity[path[len-1]] == parity(path[len-1], root).
    // path[i] for i<len-1: parity(path[i], root) = parity[path[i]] (현재값) XOR parity(path[i+1], root).
    // 거꾸로 순회하면 parity[path[i+1]] 가 이미 갱신된 상태.
    for (int i = pathBuf.length - 1; i >= 0; i--) {
      final int node = pathBuf[i];
      if (i < pathBuf.length - 1) {
        parity[node] ^= parity[pathBuf[i + 1]];
      }
      parent[node] = root;
    }
    final int xParity = pathBuf.isEmpty ? 0 : parity[pathBuf[0]];
    return [root, xParity];
  }

  bool unionPair(int x, int y, int requiredParity) {
    final List<int> rx = findInfo(x);
    final List<int> ry = findInfo(y);
    if (rx[0] == ry[0]) {
      // 같은 component. 기존 parity 가 required 와 일치해야.
      return (rx[1] ^ ry[1]) == requiredParity;
    }
    final int rootX = rx[0];
    final int rootY = ry[0];
    // rootX→rootY parity = rx[1] XOR requiredParity XOR ry[1]
    final int newParity = rx[1] ^ requiredParity ^ ry[1];
    if (rankArr[rootX] < rankArr[rootY]) {
      parent[rootX] = rootY;
      parity[rootX] = newParity;
    } else if (rankArr[rootX] > rankArr[rootY]) {
      parent[rootY] = rootX;
      parity[rootY] = newParity;
    } else {
      parent[rootY] = rootX;
      parity[rootY] = newParity;
      rankArr[rootX]++;
    }
    return true;
  }

  int cellIdx(int r, int c) => r * cols + c;

  // 1단계: 결정된 edge 로부터 parity 제약 수집.
  // 수평 edge: w[2*i][j] — cell (i-1, j) 위쪽과 cell (i, j) 사이.
  for (int i = 0; i <= rows; i++) {
    final int ei = 2 * i;
    final List<int> row = w[ei];
    for (int j = 0; j < row.length; j++) {
      final int v = row[j];
      if (v != 1 && v != -1) continue;
      final int p = v == 1 ? 1 : 0;
      final int a = (i == 0) ? outsideIdx : cellIdx(i - 1, j);
      final int b = (i == rows) ? outsideIdx : cellIdx(i, j);
      if (!unionPair(a, b, p)) return false;
    }
  }
  // 수직 edge: w[2*i+1][j] — cell (i, j-1) 와 cell (i, j) 사이.
  for (int i = 0; i < rows; i++) {
    final int ei = 2 * i + 1;
    final List<int> row = w[ei];
    for (int j = 0; j < row.length; j++) {
      final int v = row[j];
      if (v != 1 && v != -1) continue;
      final int p = v == 1 ? 1 : 0;
      final int a = (j == 0) ? outsideIdx : cellIdx(i, j - 1);
      final int b = (j == cols) ? outsideIdx : cellIdx(i, j);
      if (!unionPair(a, b, p)) return false;
    }
  }

  // 2단계: 미정 edge 에서 양쪽 parity 관계가 결정되어 있으면 forced.
  // mutation 좌표를 따로 저장 — 사후 일관성 검증에서 fail 하면 rollback.
  final List<int> mutations = [];
  for (int i = 0; i <= rows; i++) {
    final int ei = 2 * i;
    final List<int> row = w[ei];
    for (int j = 0; j < row.length; j++) {
      if (row[j] != 0) continue;
      final int a = (i == 0) ? outsideIdx : cellIdx(i - 1, j);
      final int b = (i == rows) ? outsideIdx : cellIdx(i, j);
      final List<int> rx = findInfo(a);
      final List<int> ry = findInfo(b);
      if (rx[0] != ry[0]) continue;
      final int requiredParity = rx[1] ^ ry[1];
      row[j] = requiredParity == 1 ? 1 : -1;
      mutations.add(ei * 1024 + j);
    }
  }
  for (int i = 0; i < rows; i++) {
    final int ei = 2 * i + 1;
    final List<int> row = w[ei];
    for (int j = 0; j < row.length; j++) {
      if (row[j] != 0) continue;
      final int a = (j == 0) ? outsideIdx : cellIdx(i, j - 1);
      final int b = (j == cols) ? outsideIdx : cellIdx(i, j);
      final List<int> rx = findInfo(a);
      final List<int> ry = findInfo(b);
      if (rx[0] != ry[0]) continue;
      final int requiredParity = rx[1] ^ ry[1];
      row[j] = requiredParity == 1 ? 1 : -1;
      mutations.add(ei * 1024 + j);
    }
  }

  if (mutations.isEmpty) return false;

  // 사후 검증: coloring 이 마킹한 결과가 cell quota / 꼭짓점 차수 와 충돌하면
  // (예: 0-인접 1-셀이 모든 edge -1 으로 starved) 전체 mutation 을 rollback.
  // 솔버에게 가짜 forced 를 흘려보내지 않는다.
  if (!isWorkingStateConsistent(w, rows, cols, nums)) {
    for (final pos in mutations) {
      w[pos ~/ 1024][pos & 1023] = 0;
    }
    return false;
  }
  return true;
}

/// direct propagation + coloring propagation 를 fixed-point 까지 교대로
/// 반복한다. coloring 자체 mutation 후에는 cell/vertex 일관성 검증으로 잘못된
/// forced 를 거른다 (propagateColoringSquare 내부에서 rollback). 그래도 외부
/// loop 가 안전망 (둘 다 변화 없을 때 종료, 외부 cap 20).
void propagateDirectAndColoringSquare(
    List<List<int>> w, int rows, int cols, List<List<int>> nums) {
  int outerIter = 0;
  while (outerIter < 20) {
    outerIter++;
    propagateDirectSquare(w, rows, cols, nums);
    final bool coloringChanged = propagateColoringSquare(w, rows, cols, nums);
    if (!coloringChanged) return;
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

/// Slitherlink 의 전역 위상 조건: 그어진 모든 edge 는 정확히 하나의 닫힌 고리를
/// 이뤄야 한다. cell/vertex 차수만 보는 [isWorkingStateConsistent] 는 이를
/// 검출하지 못해, 부분 분기 결과가 여러 개의 분리 고리로 수렴해도 통과한다.
///
/// 이 함수는 union-find 로 그어진 edge 의 연결 성분을 추적하고:
///   • 모든 touched vertex 가 degree 2 인 성분 (= 닫힌 고리) 이 2개 이상이거나
///   • 닫힌 고리 1개 + 다른 성분에 추가 edge 가 남아 있으면
/// 위상이 어긋난 것으로 보고 true 를 반환한다. 닫힌 고리가 없거나 (아직 진행 중)
/// 단일 성분뿐이면 false.
bool hasInconsistentLoopTopology(
    List<List<int>> w, int rows, int cols) {
  final int vCols = cols + 1;
  final int nv = (rows + 1) * vCols;
  final List<int> parent = List<int>.generate(nv, (i) => i);
  int find(int x) {
    int r = x;
    while (parent[r] != r) {
      r = parent[r];
    }
    while (parent[x] != r) {
      final int next = parent[x];
      parent[x] = r;
      x = next;
    }
    return r;
  }

  final List<int> deg = List<int>.filled(nv, 0);
  final List<bool> touched = List<bool>.filled(nv, false);

  for (int i = 0; i <= 2 * rows; i++) {
    final List<int> row = w[i];
    if (i.isEven) {
      final int vi = i ~/ 2;
      for (int j = 0; j < row.length; j++) {
        if (row[j] != 1) continue;
        final int a = vi * vCols + j;
        final int b = vi * vCols + (j + 1);
        deg[a]++;
        deg[b]++;
        touched[a] = true;
        touched[b] = true;
        final int ra = find(a);
        final int rb = find(b);
        if (ra != rb) parent[ra] = rb;
      }
    } else {
      final int viTop = (i - 1) ~/ 2;
      for (int vj = 0; vj < row.length; vj++) {
        if (row[vj] != 1) continue;
        final int a = viTop * vCols + vj;
        final int b = (viTop + 1) * vCols + vj;
        deg[a]++;
        deg[b]++;
        touched[a] = true;
        touched[b] = true;
        final int ra = find(a);
        final int rb = find(b);
        if (ra != rb) parent[ra] = rb;
      }
    }
  }

  final Map<int, bool> closedFlag = {};
  for (int v = 0; v < nv; v++) {
    if (!touched[v]) continue;
    final int r = find(v);
    final bool deg2 = deg[v] == 2;
    if (!closedFlag.containsKey(r)) {
      closedFlag[r] = deg2;
    } else if (!deg2) {
      closedFlag[r] = false;
    }
  }

  int closedCount = 0;
  for (final entry in closedFlag.entries) {
    if (entry.value) closedCount++;
  }
  if (closedCount >= 2) return true;
  if (closedCount == 1 && closedFlag.length > 1) return true;
  return false;
}

/// Slitherlink 의 답 위상: 정확히 하나의 닫힌 고리만 존재하고 그 외 그어진
/// edge 가 없어야 한다. 답안 (`answer`) 이 다중 고리 등 잘못 생성되었을 때도
/// "퍼즐 완료" 다이얼로그/솔버 종료 가 트리거되지 않도록 방어용 검사.
/// 그어진 edge 가 하나도 없으면 false.
bool isSingleClosedLoop(List<List<int>> w, int rows, int cols) {
  final int vCols = cols + 1;
  final int nv = (rows + 1) * vCols;
  final List<int> parent = List<int>.generate(nv, (i) => i);
  int find(int x) {
    int r = x;
    while (parent[r] != r) {
      r = parent[r];
    }
    while (parent[x] != r) {
      final int next = parent[x];
      parent[x] = r;
      x = next;
    }
    return r;
  }

  final List<int> deg = List<int>.filled(nv, 0);
  final List<bool> touched = List<bool>.filled(nv, false);
  int drawnCount = 0;

  for (int i = 0; i <= 2 * rows; i++) {
    final List<int> row = w[i];
    if (i.isEven) {
      final int vi = i ~/ 2;
      for (int j = 0; j < row.length; j++) {
        if (row[j] != 1) continue;
        drawnCount++;
        final int a = vi * vCols + j;
        final int b = vi * vCols + (j + 1);
        deg[a]++;
        deg[b]++;
        touched[a] = true;
        touched[b] = true;
        final int ra = find(a);
        final int rb = find(b);
        if (ra != rb) parent[ra] = rb;
      }
    } else {
      final int viTop = (i - 1) ~/ 2;
      for (int vj = 0; vj < row.length; vj++) {
        if (row[vj] != 1) continue;
        drawnCount++;
        final int a = viTop * vCols + vj;
        final int b = (viTop + 1) * vCols + vj;
        deg[a]++;
        deg[b]++;
        touched[a] = true;
        touched[b] = true;
        final int ra = find(a);
        final int rb = find(b);
        if (ra != rb) parent[ra] = rb;
      }
    }
  }

  if (drawnCount == 0) return false;

  final Set<int> roots = {};
  for (int v = 0; v < nv; v++) {
    if (!touched[v]) continue;
    if (deg[v] != 2) return false;
    roots.add(find(v));
  }
  return roots.length == 1;
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
  // Iter cap. 16×11 hard 보드의 forcing chain 깊이가 12 를 넘는 경우가 있어
  // 60 으로 인상 — partial 상태로 종료해 topology check 가 false-positive 를
  // 만드는 무한 루프(docs/auto_solver_termination_analysis.md §1) 방지.
  // 실측: 일반 보드에선 여전히 2-5 iter 안에 fixed-point 도달.
  const int kIterCap = 60;
  while (changed && iter < kIterCap) {
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
  // 직접규칙/꼭짓점 규칙이 fixed-point 에 도달했다면 (changed==false), sub-loop
  // 가 닫히는 가설은 위상상 모순이다. 이 검사가 없으면 가설 propagation 이
  // "OK" 로 반환되고 solver 가 잘못된 분기 후보로 받아들여, 추측 → 사후
  // backtrack 의 비용을 매번 지불한다.
  //
  // **중요**: iter cap 으로 미수렴 종료한 경우 (changed==true) topology check
  // 를 절대 호출하지 않는다. partial state 에는 아직 propagation 으로 disable
  // 될 예정인 미정 변이 남아 transient 한 닫힌 sub-loop 으로 union-find 가
  // 오인할 수 있다. false-positive 모순 → false-positive forced-disable →
  // 솔버 무한 루프 (docs/auto_solver_termination_analysis.md §1).
  if (!changed && hasInconsistentLoopTopology(w, rows, cols)) {
    return true;
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

// ---------------------------------------------------------------------------
// Pure, answer-free DFS solver.
//
// Everything above either propagates one step or scores a single guess. The
// functions below tie them into a *complete* search that never looks at any
// stored answer — it only consumes the visible clues in `nums` (num < 0 =
// hidden, skipped by every rule). This is the shared foundation for both the
// visible auto-solver (take the first solution and replay it onto the board)
// and puzzle verification (count solutions: exactly 1 → a proper puzzle).
// ---------------------------------------------------------------------------

/// An empty canonical working grid (all 0 = undecided) sized for a
/// rows×cols clue board: even rows hold `cols` horizontal edges, odd rows
/// hold `cols + 1` vertical edges.
List<List<int>> emptyWorkingGrid(int rows, int cols) {
  return List.generate(2 * rows + 1,
      (i) => List<int>.filled(i.isEven ? cols : cols + 1, 0));
}

/// True iff every edge in `w` is decided (no 0 remains).
bool _allEdgesDecided(List<List<int>> w) {
  for (final row in w) {
    for (final v in row) {
      if (v == 0) return false;
    }
  }
  return true;
}

/// Propagate `w` to a fixed point using the cheap direct/vertex/cell rules
/// (via [propagateHypothesisSquare], which also force-draws) interleaved with
/// the inside/outside coloring pass. Returns true on a detected contradiction.
///
/// Note: [propagateColoringSquare] rolls back and returns false both when it
/// makes no progress *and* when it hits a parity contradiction without marking
/// — so we can't treat its false as a hard contradiction. That only costs a
/// little extra search; the completeness checks in the DFS reject any invalid
/// full assignment, so correctness is unaffected.
bool _propagateToFixedPoint(
    List<List<int>> w, int rows, int cols, List<List<int>> nums) {
  while (true) {
    if (propagateHypothesisSquare(w, rows, cols, nums)) return true;
    final bool coloringChanged = propagateColoringSquare(w, rows, cols, nums);
    if (!coloringChanged) return false;
    // Coloring marked new edges; loop so the direct rules can consume them.
  }
}

/// A fully-decided working grid is a real solution iff it satisfies every
/// visible clue and forms exactly one closed loop.
bool _isCompleteSolution(
    List<List<int>> w, int rows, int cols, List<List<int>> nums) {
  if (!_allEdgesDecided(w)) return false;
  // With no undecided edges, isWorkingStateConsistent collapses to
  // "drawn count == clue" per cell and vertex degree ∈ {0, 2}.
  if (!isWorkingStateConsistent(w, rows, cols, nums)) return false;
  return isSingleClosedLoop(w, rows, cols);
}

/// Depth-first search over the canonical edge grid. Collects up to
/// [solutionCap] distinct complete solutions (each a fresh 1/-1 grid) into
/// [out]. Branches on the first undecided edge, trying drawn (1) then
/// disabled (-1), pruning with full propagation + consistency/topology checks
/// at every node. Honours [nodeLimit]: when the node budget is exhausted the
/// search aborts early and [budgetExhausted] is set so callers can tell an
/// "unsolved" result apart from a "gave up" one.
class _SquareDfs {
  _SquareDfs(this.rows, this.cols, this.nums,
      {required this.solutionCap, this.nodeLimit, this.timeBudget});

  final int rows;
  final int cols;
  final List<List<int>> nums;
  final int solutionCap;
  final int? nodeLimit;

  /// Wall-clock budget. When exceeded the search aborts and [budgetExhausted]
  /// is set — callers treat that as "inconclusive" rather than "no solution",
  /// so a slow big board never blocks the UI thread indefinitely.
  final Duration? timeBudget;
  final Stopwatch _sw = Stopwatch();

  final List<List<List<int>>> out = [];
  int _nodes = 0;
  bool budgetExhausted = false;

  void run(List<List<int>> start) {
    if (timeBudget != null) _sw.start();
    _dfs(start);
  }

  void _dfs(List<List<int>> w) {
    if (out.length >= solutionCap || budgetExhausted) return;
    final int n = _nodes++;
    if (nodeLimit != null && n >= nodeLimit!) {
      budgetExhausted = true;
      return;
    }
    if (timeBudget != null && (n & 0x3F) == 0 && _sw.elapsed > timeBudget!) {
      budgetExhausted = true;
      return;
    }

    if (_propagateToFixedPoint(w, rows, cols, nums)) return; // contradiction
    if (!isWorkingStateConsistent(w, rows, cols, nums)) return;
    if (hasInconsistentLoopTopology(w, rows, cols)) return;

    int er = -1, ec = -1;
    outer:
    for (int i = 0; i < w.length; i++) {
      final List<int> row = w[i];
      for (int j = 0; j < row.length; j++) {
        if (row[j] == 0) {
          er = i;
          ec = j;
          break outer;
        }
      }
    }

    if (er == -1) {
      if (_isCompleteSolution(w, rows, cols, nums)) {
        out.add(w.map((r) => List<int>.from(r)).toList());
      }
      return;
    }

    for (final int val in const [1, -1]) {
      if (out.length >= solutionCap || budgetExhausted) return;
      final List<List<int>> branch = w.map((r) => List<int>.from(r)).toList();
      branch[er][ec] = val;
      _dfs(branch);
    }
  }
}

/// Solve the board from the visible clues alone. Returns the solution working
/// grid (1 = drawn, -1 = not drawn) or null if no solution exists / the node
/// budget was exhausted before one was found.
List<List<int>>? solveSquareFromClues(
    List<List<int>> nums, int rows, int cols,
    {int? nodeLimit, Duration? timeBudget}) {
  final dfs = _SquareDfs(rows, cols, nums,
      solutionCap: 1, nodeLimit: nodeLimit, timeBudget: timeBudget);
  dfs.run(emptyWorkingGrid(rows, cols));
  return dfs.out.isEmpty ? null : dfs.out.first;
}

/// compute() 진입점 — solveSquareFromClues 를 백그라운드 isolate 에서 실행해
/// 자동풀기의 동기 DFS 추론이 UI 스레드를 블로킹(앱 멈춤)하지 않게 한다.
/// 큰 보드에서 nodeLimit/timeBudget 까지 도는 동안에도 화면이 응답을 유지한다.
/// [timeBudgetMs] 는 방어용 백스톱 — 정상적으로는 검증을 통과한 보드만
/// 자동풀기되므로 예산 안에 끝나지만, 이상 상황에서 isolate 가 무한정 도는 것을
/// 막는다(초과 시 null → solver_stuck 으로 정상 종료).
List<List<int>>? solveSquareFromCluesIsolate(Map<String, dynamic> params) {
  final List<List<int>> nums = (params['nums'] as List)
      .map((r) => List<int>.from(r as List))
      .toList();
  final int? tbMs = params['timeBudgetMs'] as int?;
  return solveSquareFromClues(
      nums, params['rows'] as int, params['cols'] as int,
      nodeLimit: params['nodeLimit'] as int?,
      timeBudget: tbMs == null ? null : Duration(milliseconds: tbMs));
}

/// Outcome of verifying a board against the visible clues.
enum SquareVerifyResult {
  /// Exactly one solution exists — a proper, well-formed puzzle.
  unique,

  /// More than one solution exists — the clues are ambiguous.
  multiple,

  /// No solution satisfies the visible clues.
  none,

  /// The search hit its node budget before resolving — result unknown.
  timeout,
}

/// Verify a board from the visible clues only. Counts solutions up to two
/// (enough to distinguish unique from ambiguous) under an optional node
/// budget. Never references any stored answer.
SquareVerifyResult verifySquareFromClues(
    List<List<int>> nums, int rows, int cols,
    {int? nodeLimit}) {
  final dfs = _SquareDfs(rows, cols, nums, solutionCap: 2, nodeLimit: nodeLimit);
  dfs.run(emptyWorkingGrid(rows, cols));
  if (dfs.out.length >= 2) return SquareVerifyResult.multiple;
  if (dfs.out.length == 1) return SquareVerifyResult.unique;
  return dfs.budgetExhausted
      ? SquareVerifyResult.timeout
      : SquareVerifyResult.none;
}

/// 백그라운드 검증용: 시간 예산 내에서 자동풀기(추측+백트래킹 완전탐색)로
/// 풀리는지. **예산 안에 해를 찾았을 때만 true** 다. 예산 초과(미결)는 false 로
/// 본다 — 이 보드는 자동풀기가 예산 안에 못 끝낸다는 뜻이므로 씬이 재생성한다.
/// 이렇게 통과한 보드는 (검증이 사용자 기기에서 돌므로) 그 기기에서 예산 내에
/// 풀리는 게 보장되어, 사용자가 자동풀기를 눌렀을 때 항상 빠르게 끝난다.
/// (과거엔 예산 초과도 true 로 수용했는데, 그 결과 20x20 normal 같은 보드가
/// 새어 나와 자동풀기가 수십 초 걸렸다 — 분포상 절반가량은 빠르므로 재생성
/// 으로 빠른 보드를 뽑는 편이 사용자 경험에 낫다.) 정답 비참조.
bool canAutoSolveSquareFromClues(List<List<int>> nums, int rows, int cols,
    {Duration timeBudget = const Duration(milliseconds: 400)}) {
  final dfs = _SquareDfs(rows, cols, nums,
      solutionCap: 1, timeBudget: timeBudget);
  dfs.run(emptyWorkingGrid(rows, cols));
  if (dfs.out.isNotEmpty) return true; // 예산 내 해 찾음 → 수용
  return false; // 미결(예산 초과) 또는 해 없음 → 재생성
}

/// "공정한 퍼즐" 검증: 추측(branching) 없이 보이는 단서만으로 끝까지 풀리는지.
/// direct+coloring 전파와 모순기반 forced draw/disable 만 반복 적용한다.
/// 완성된 단일 닫힌 고리에 도달하면 true; 더 둘 forced 수가 없는데 미정 변이
/// 남으면(=사람이 추측해야 함) false. 모순/미완성도 false.
///
/// 정답을 전혀 참조하지 않으며, 퍼즐 생성 직후 백그라운드 검증에 쓴다 —
/// 통과한 보드만 사용자에게 노출해 "막히지 않고 논리로 풀리는" 경험을 보장.
bool isSquareLogicSolvable(List<List<int>> nums, int rows, int cols) {
  final List<List<int>> w = emptyWorkingGrid(rows, cols);
  // 안전망: edge 총수보다 넉넉히. 매 반복 최소 한 변이 확정되므로 충분.
  int totalEdges = 0;
  for (final row in w) {
    totalEdges += row.length;
  }
  final int maxIter = totalEdges + 10;
  for (int iter = 0; iter < maxIter; iter++) {
    propagateDirectAndColoringSquare(w, rows, cols, nums);
    if (!isWorkingStateConsistent(w, rows, cols, nums)) return false;
    if (hasInconsistentLoopTopology(w, rows, cols)) return false;
    if (_allEdgesDecided(w)) {
      return _isCompleteSolution(w, rows, cols, nums);
    }
    final List<int>? draw = findForcedDrawByContradiction(w, rows, cols, nums);
    if (draw != null) {
      w[draw[0]][draw[1]] = 1;
      continue;
    }
    final List<int>? disable =
        findForcedDisableByContradiction(w, rows, cols, nums);
    if (disable != null) {
      w[disable[0]][disable[1]] = -1;
      continue;
    }
    return false; // 확정 수 없음 → 추측 필요 → 불공정
  }
  return false;
}
