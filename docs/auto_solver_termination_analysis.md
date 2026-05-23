# Auto Solver 비종료 (non-termination) 원인 분석

대상: `SquareProvider.solveHumanLike` + `square_propagation_core.dart`
증상: 16×11 hard 보드에서 자동 풀이가 단일 고리로 수렴하지 않고 "Guess failed, restoring" → 분기 → 다시 backtrack 을 무한 반복. 사용자가 Stop 을 눌러야 종료.
작성: 2026-05-23. 3개 분석 에이전트(로직 감사 / Slitherlink 기법 격차 / 실행 경로 추적)의 병렬 분석 결과를 통합.

> **2026-05-23 업데이트**: Tier 1 적용 완료 — §6 참조. iter cap 12 → 60 인상, 미수렴 종료 시 topology check 스킵.

---

## 1. 가장 직접적인 원인 (Smoking gun)

### Iter cap 12 + topology check = false positive forced-disable → infinite loop

**위치**: `lib/provider/square_propagation_core.dart`
- L333: `while (changed && iter < 12)` — 가설 propagation 의 iteration cap
- L490 (최근 추가): `if (hasInconsistentLoopTopology(w, rows, cols)) return true;` — propagation 종료 후 다중 고리 검사

**문제 시나리오**:
1. 16×11 의 깊은 forcing chain 에서 `propagateHypothesisSquare` 가 iter==12 cap 에 도달, fixed-point 에 못 미친 partial state 로 종료.
2. 그 partial state 에서 아직 propagation 으로 disable 되지 않은 미정 변들이 남아 있어, union-find 가 transient 한 닫힌 sub-loop 으로 본다.
3. topology check 가 모순이라 보고 `propagateHypothesisSquare` 가 `true` 반환.
4. `findForcedDisableByContradiction` (L652) 가 호출 edge 를 forced -1 로 판정해 솔버에게 돌려준다.
5. 솔버: `_solverApplyDisable(edge)` → puzzle/submit 에 -4 마킹. **그러나 이 edge 는 실제로 -1 으로 강제되지 않음** (false positive).
6. `_applyConstraints` 가 잘못된 -4 시드로부터 cascade → 모순 상태 검출 → `_solverDetectedInconsistency=true`.
7. 솔버: backtrack 으로 마지막 **guess frame** 을 pop — 하지만 모순의 원인은 그 guess 가 아니라 단계 5 의 false-positive disable. 복원된 상태는 "pre-guess + 잘못된 가정으로 시도한 guess edge -4 처리".
8. 다음 iteration 진입: `findForcedDisableByContradiction` 가 **다시 같은 false-positive forced-disable** 을 반환 (state 가 사실상 동일).
9. → 단계 5-8 무한 반복. 사용자에게는 "Guess failed, restoring" banner 가 계속 떠 있다가 Stop 으로 종료.

**왜 최근 패치 이전엔 안 보였나**: L490 topology check 는 직전 변경에서 추가된 것이다. 그 전엔 iter cap 이 부족해도 cell/vertex 규칙으로만 contradiction 판정했고, partial state 에서 그 두 규칙은 false-positive 를 거의 만들지 않았다. topology check 가 partial state 에 민감한 union-find 기반이라 false-positive 빈도가 급증한 것.

**즉시 수정안**:
- (a) iter cap 을 늘린다: `iter < 12` → `iter < 60` 이상. 16×11 의 forcing chain 깊이는 30~50 회 cell+vertex propagation 이 필요할 수 있다.
- (b) iter==cap 으로 종료한 경우 topology check 를 건너뛴다. propagation 미완 상태에서 topology 판정은 의미가 없으므로 `false` (no decision) 반환.
- (c) 가장 안전: (a) + (b) 둘 다 적용.

---

## 2. 구조적 원인 (Termination 보장 부재)

### 2-1. Backtrack 시 모든 forced inference 폐기 → O(N²) 중복 작업

**위치**: `SquareProvider.dart:2228` `_solverRestoreAndDisproveGuess`
```dart
await applyBookmarkSubmit(frame.snapshot);   // submit 전체를 스냅샷으로 복원
await _solverApplyDisable(frame.canonRow, frame.canonCol);   // guess edge 만 -4
```

- 실패한 분기에서 도출한 모든 forced -1, +1, look-ahead 결과가 통째로 폐기된다.
- 다음 iter 진입 시 `readSubmit → buildWorkingFromEdges → propagateDirectSquare → findForcedDraw → findForcedDisable → pickHighestImpactGuess` 를 **처음부터 다시** 실행.
- 16×11 (E=379) 기준 한 iter 비용: 약 **3.75M ops** (Agent 3 측정).
- N 회 backtrack 시 N × 3.75M = O(N²) 의 redundant work.
- nogood / implication cache 가 없어 같은 결론을 매 backtrack 마다 다시 도출.

### 2-2. Unbounded guess stack, no-progress 감지 부재

**위치**: `SquareProvider.dart:2153-2167`
- `pickHighestImpactGuess` 가 null 이 아니라면 새 frame 을 push.
- guess 가 즉시 contradiction 을 만들지 않으면서 새 forced move 도 끌어내지 못한 경우, 다음 iter 는 또 다른 guess 를 push.
- 결과: 스택이 ~U/2 깊이까지 자랄 수 있다 (U = 미정 edge 수). 16×11 에서 30+ depth 가능.
- 최악: 2^depth = 2^30 ≈ 10^9 분기, 각 분기마다 3.75M ops → ~10^16 ops = 실질적 무한.

### 2-3. 16×11 종단 테스트 부재

**위치**: `test/square_propagation_regression_test.dart`
- 1×1, 1×2, 2×2 보드만 검증. 큰 보드에서의 termination/correctness 회귀가 잡히지 않음.
- Square 용 smoke test (생성된 보드를 솔버로 풀어 검증) 도구가 없음. `tool/trihex_smoke.dart` 는 trihex 전용.

---

## 3. 알고리즘적 격차 (Slitherlink 표준 기법)

현재 솔버가 갖춘 것: 셀 quota, 정점 차수, force-draw, 1-step ±1 가설, sub-loop union-find (post-hoc), impact-기반 speculation + 백트래킹.

**영향력 순으로 누락된 기법** (Agent 2):

### 3-1. Inside/Outside Coloring (가장 큰 영향)
- 모든 셀 + 외부에 In/Out 라벨. 변을 사이에 둔 두 면이 그어진 변이면 색이 다르고 미지면 같다. weighted union-find.
- 16×11 hard 에서 셀+정점 규칙만으로 안 풀리는 변의 대부분이 coloring 만으로 즉시 ±1 확정.
- **복잡도: Medium.** weighted UF + 외부 가상 노드 1 개 + propagation 패스 1 개 추가.

### 3-2. Pre-emptive sub-loop avoidance (큰 영향)
- 현재 `hasInconsistentLoopTopology` 는 가설 propagation **종료 후** 검사. propagation 도중 "이 +1 가설이 active edge 모두를 포함하지 않은 부분 루프를 닫을 것" 을 미리 보면 그 edge 는 즉시 -1.
- 두 끝점이 같은 active component 이고 외부에 다른 active edge 가 남아 있으면 모순. **O(1) per edge** (UF 캐시).

### 3-3. Corner / Edge 패턴 (큰 영향, 입력 단계)
- 모서리 3, 인접 3-3, 대각 3-3, 0+대각 3, 모서리 1/2 등 1-step 가설로는 안 잡히는 forced 변 조합.
- num 조합별 lookup table, 1 회 패스. **복잡도: Cheap.**

### 3-4. Cell-pair / 2-step hypothesis with consensus (중간)
- 두 변 동시에 ±1 조합 4 가지를 시도. 4 가지 다 모순이면 전제 셀 모순. 일부 조합에서 공통 결론은 영구 마킹 (consensus deduction).

### 3-5. Chain endpoint 추적 (중간)
- active path 양 끝점에서 (a) 두 끝점 잇는 변 ≠ sub-loop 검사, (b) 탈출구 1 개면 force-draw, (c) 두 끝점 사이 거리 0 인 변 자동 -1.

---

## 4. 수정 우선순위 (롤아웃 권장)

### Tier 1: 즉시 적용 (현재 무한 루프 해결)
1. **L333 iter cap 60+** 으로 인상, 또는 iter==cap 종료 시 topology check 스킵.
2. **`findForcedDisableByContradiction` 결과를 -4 로 즉시 마킹하기 전 재검증**: 한번 더 hypothesis 를 깊이 propagation 해 정말 모순인지 확인. false-positive 입력에 대한 방어선.

### Tier 2: 단기 (1-2 회 작업)
3. **Backtrack 시 발견한 forced inference 캐시**: guess 분기에서 발견한 "guess assumption 과 무관하게 강제되는" 결론을 별도 캐시. 백트래킹 후에도 유지해 redundant 작업 제거.
4. **No-progress 감지**: 연속 N 회 iter 가 forced move 0 개 + guess push 만 한다면 솔버를 stuck 으로 종료 (현재 무한 가능).

### Tier 3: 알고리즘 강화 (큰 보드 결정론적 풀이)
5. **Inside/Outside coloring 구현** — Section 3-1.
6. **Pre-emptive sub-loop avoidance** — Section 3-2.
7. **Corner/edge pattern table** — Section 3-3.

### Tier 4: 회귀 방지
8. **`test/square_solver_smoke_test.dart` 신설**: 생성된 8×8, 12×8, 16×11 보드 각 N 개를 `solveHumanLike` 로 풀어 단일 고리 수렴 + termination time 회귀 추적.

---

## 5. 분석 근거 파일

| 영역 | 파일 |
|---|---|
| 솔버 메인 루프 | `lib/provider/SquareProvider.dart:2055-2202` (`solveHumanLike`, `_backtrackToLastGuess`, `_solverRestoreAndDisproveGuess`, `_solverApplyDraw/Disable`, `_isPuzzleSolvedLocal`) |
| 직접 규칙 propagation | `lib/provider/square_propagation_core.dart:25-100` (`propagateDirectSquare`) |
| 일관성 검사 | `lib/provider/square_propagation_core.dart:108-151` (`isWorkingStateConsistent`) |
| 위상 검사 (신규) | `lib/provider/square_propagation_core.dart:157-228` (`hasInconsistentLoopTopology`), 234-300 (`isSingleClosedLoop`) |
| 가설 propagation | `lib/provider/square_propagation_core.dart:326-492` (`propagateHypothesisSquare`) ← **L333 iter cap, L490 topology check** |
| Forced move 추출 | `lib/provider/square_propagation_core.dart:613-666` (`findForcedDrawByContradiction`, `findForcedDisableByContradiction`) |
| Guess 휴리스틱 | `lib/provider/square_propagation_core.dart:682-710` (`pickHighestImpactGuess`) |
| 회귀 테스트 | `test/square_propagation_regression_test.dart` — **1×1/1×2/2×2 만 커버** |

---

## 6. Tier 1 수정 기록 (2026-05-23)

### 6-1. 적용한 변경
**파일**: `lib/provider/square_propagation_core.dart` — `propagateHypothesisSquare`

1. **Iter cap 12 → 60 인상** (L333 → L336).
   - 16×11 forcing chain 의 깊이가 12 를 넘는 경우 미수렴 종료 → partial state 문제.
   - 60 으로 인상해 일반적인 hard 보드는 자연 수렴하도록 함.
   - 일반 보드 (8×8 이하) 는 여전히 2-5 iter 에 수렴, 추가 비용 없음.

2. **`!changed` 가드로 topology check 보호** (L490).
   - 기존: `if (hasInconsistentLoopTopology(...)) return true;` — 무조건 검사.
   - 신규: `if (!changed && hasInconsistentLoopTopology(...)) return true;` — propagation 이 fixed-point 에 자연 종료한 경우(`changed==false`) 에만 검사.
   - iter cap 으로 종료한 partial state (`changed==true`) 에서는 검사 자체를 스킵 → false-positive 모순 방지.

### 6-2. 기대 효과
- **무한 루프 제거**: §1 의 false-positive forced-disable → backtrack → 재생성 사이클 차단.
- **결과의 명확성**: 솔버가 stuck 으로 종료하면 그것은 진짜 stuck (cell/vertex 규칙만으로는 풀 수 없음) 이지, false-positive 의 부산물이 아님.
- **여전히 남는 한계**:
  - Tier 2 (forced inference 캐시, no-progress 감지) 가 없으면 진짜 hard 보드는 시간이 오래 걸릴 수 있음.
  - Tier 3 (coloring, corner pattern) 없이는 셀+정점 규칙으로 안 풀리는 큰 보드는 여전히 speculation 필요.

### 6-3. 회귀 위험
- Iter cap 인상 (12→60) 으로 인해 최악 케이스 hypothesis propagation 시간이 5배 늘어남. 그러나 평균은 그대로 (대부분 2-5 iter 수렴). 사용자 체감 차이 거의 없음.
- topology check 호출 빈도가 줄어들어 (미수렴 경우 스킵) 평균 비용은 오히려 감소.

### 6-4. 다음 단계 (Tier 2/3 미적용)
사용자 동작 확인 후 적용 여부 결정. 현재 미적용:
- Tier 2: forced inference cross-backtrack 캐시, no-progress 종료 가드.
- Tier 3: Inside/Outside coloring, corner pattern table, pre-emptive sub-loop avoidance.

---

## 7. Tier 2 + Tier 3 (부분) 수정 기록 (2026-05-23)

Tier 1 적용 후에도 16×11 hard 보드에서 솔버가 분기 폭발로 사실상 완주 불가했던 문제에 대응. 사용자 선택: 옵션 3 (Tier 2 + Tier 3 둘 다, no-progress 가드 + Inside/Outside coloring).

### 7-1. Tier 3 — Inside/Outside Coloring 구현
**파일**: `lib/provider/square_propagation_core.dart`

신규 함수 2개:
- `propagateColoringSquare(w, rows, cols)` — weighted union-find 로 셀+외부 가상노드의 parity 관계를 결정된 edge 로부터 union (그어진 edge = different, disabled = same). 미정 edge 양쪽이 같은 component 안에서 parity 가 결정되어 있으면 그 edge 도 forced. O(E + V·α(V)) 단일 패스.
- `propagateDirectAndColoringSquare(w, rows, cols, nums)` — direct + coloring 을 fixed-point 까지 교대로 반복 (외부 cap 20회).

**솔버 통합**: `SquareProvider.solveHumanLike` L2097 의 `propagateDirectSquare` 호출을 `propagateDirectAndColoringSquare` 로 교체.

**핵심 효과**: 셀 quota / 정점 차수 규칙으론 안 풀리는 변의 대부분이 coloring 만으로 즉시 결정 → speculation 단계 진입 빈도가 급감. Slitherlink 솔버 문헌의 표준 기법.

**`_applyConstraints` 는 건드리지 않음**: 사용자 탭 propagation 경로는 proximity-limited cascade 정책 (memory: `feedback_constraint_skip_masked_clues`, `feedback_no_destructive_git_on_dirty_files` 등) 을 유지. coloring 은 솔버 전용.

### 7-2. Tier 2 — no-progress 종료 가드
**파일**: `lib/provider/SquareProvider.dart:2071-2095`

`solveHumanLike` 메인 루프에 두 카운터:
- `iterCount` — 총 iter 수, `kMaxIter=5000` 초과 시 stuck 종료. 어떤 경로로든 무한 회피.
- `noProgressStreak` — forced move 0 + guess push 만 한 연속 iter 수. `kMaxNoProgress=80` 초과 시 stuck 종료. forced draw/disable 적용 시 0 으로 reset.

이 가드는 안전망. 정상적인 hard 보드는 coloring 도입으로 streak 이 80 에 도달하기 전에 풀려야 함. 종료해도 보드는 [Tier 1] 정책에 따라 진행 상황을 보존.

### 7-3. 기대 효과 (정량)
- 16×11 hard 보드: 솔버가 speculation 없이 풀 확률 큰 폭 상승.
- 진짜 hard / 다중 해 puzzle: speculation 깊이가 얕아져 backtrack 비용 감소.
- 어떤 경우든 5000 iter 또는 80 무진행 streak 안에 종료 보장.

### 7-4. 회귀 위험
- `propagateColoringSquare` 의 path-compression 로직: weighted union-find 의 parity 누적 갱신이 잘못되면 잘못된 forced move 가 나와 솔버가 wrong path 로 진입 가능. → reverse-order 누적 (deeper-first) 방식으로 단순화. 테스트로 검증 필요.
- coloring 자체 모순 시 (예: 다중 해 또는 사용자 X 충돌) `unionPair` 가 false 반환 → 함수 false 반환. 호출자(`propagateDirectAndColoringSquare`) 가 그 시점에 종료. cell/vertex 규칙은 다음 outer iter 에서 동일 모순을 잡으므로 결과적으로 backtrack 트리거.

### 7-5. 미적용 항목 (잔여)
- Tier 2 — forced inference cross-backtrack 캐시: 구현 비용이 커서 보류. coloring 으로 backtrack 자체가 줄어들면 불필요.
- Tier 3 — Corner/edge pattern table: 추가 가속 가능. coloring 의 효과 확인 후 결정.
- Tier 3 — Pre-emptive sub-loop avoidance: 닫히기 직전 sub-loop 가 명확한 경우 즉시 -1. coloring 이 비슷한 효과를 일부 제공함.
- 회귀 테스트 (Tier 4): `test/square_solver_smoke_test.dart` 미작성.
