# Square 보드: 한 탭에 -1 cascade 가 보드 전체로 퍼지는 문제 분석 및 수정

작성: 2026-05-17 | 대상 브랜치: `puzzleType` | 대상 파일: `lib/provider/SquareProvider.dart`

---

## 1. 사용자 보고 흐름 (시간순)

1. **깜빡임**: "두 상태가 클릭할 때마다 왔다갔다 한다. 누른 선에 영향을 받는 부분만 선 변경이 되어야 한다."
2. **첫 탭 cascade**: "처음 상태에서 라인 하나 클릭하면 많은 라인이 바로 비활성화 되는데, 이 문제를 해결해."
3. **요구 정의**: "-1은 사용 필요해. 누른 선에 대한 -1만 보여야 해, 아니면 0으로 보여야 하고."
4. **0-clue 자동 -1 필요**: "restart를 하니 0인 박스의 주변도 라인0으로 잘못 표기되는 문제가 발생했어." (자동 -1 마킹 제거하면 안 됨)
5. **Phase 2 잔존 cascade**: "아직도 똑같다고, restart 누르면 자동 풀기 해제되도록 해, 전파가 어디까지 뵈는지 제대로 분석해."

요구를 종합하면:
- 깜빡임 없을 것.
- 0-clue 셀 4 변 자동 -1 표시는 유지.
- 사용자 탭이 야기한 -1 만 추가, 그 외는 0 으로 유지.
- Restart 가 자동 풀기도 중지.

---

## 2. 원인 정리

### 2-1. cascade-abort 전면 복원으로 인한 토글 (깜빡임)

`_applyConstraints` 마지막에 propagation 결과의 일관성을 체크. 실패 시 진입 시점 풀스냅샷(`guardSnap`) 으로 puzzle 전체를 복원하던 구조였음.

```dart
if (!isWorkingStateConsistent(liveW, rows, cols, nums)) {
  _restorePuzzleEdges(guardSnap);                  // 보드 전체 4 방향 edge 복원
  submit = await readSquare.readSubmit(puzzle);
}
```

- 같은 자리를 cycle 탭 (0 → color → -4 → 0 …) 하면 일부 값은 consistent, 일부는 inconsistent.
- consistent → `submit = edge` (새 -1 분포 적용).
- inconsistent → 전면 복원 (prior -1 분포 유지).
- 두 분포가 다르므로 탭마다 보드 전체가 다른 모양 ↔ 사용자에게 "깜빡거림" 으로 보임.

### 2-2. `_writeWorkingToEdge` 의 -1 전면 재계산

working grid 빌드 시 기존 -1/-2 가 모두 0(undecided) 으로 매핑. propagation 이 처음부터 -1 을 다시 도출하고, `_writeWorkingToEdge` 가 그 결과로 edge 를 덮어쓰므로 prior -1 자리가 새 derivation 으로 churn.

### 2-3. cell-rule cascade

`propagateDirectSquare` 의 cell rule (`dr == num` 일 때 모든 미정 변 -1) 은 fixed-point 반복. 한 탭이 1-clue 셀의 dr 을 1 로 만들면 3 변 -1, 그로부터 인접 셀의 un 감소, 또 vertex rule … 식으로 다단계 연쇄.

### 2-4. Phase 2 look-ahead 의 deep contradiction

`propagateHypothesisSquare` 가 각 미정 edge 에 가설(=1) 적용 → 모순이면 그 edge -1 확정. 보드 멀리까지 -1 도출 가능. 사용자 탭 경로에서도 동일하게 적용됐기 때문에 incremental diff 만으로는 막을 수 없었음.

### 2-5. (관련) inner cell box-overlay 좌표 어긋남 — **본 문서에서는 미수정**

`SquareBox.dart` 의 14px overlay strip 이 inner cell 의 `.left`/`.up` 을 mutate. 그러나 readSubmit/writeSubmit 은 canonical 자리 (`.down`, `.right` for inner cells) 만 round-trip. 누른 자리와 실제 변경 위치가 다름. 별도 작업 필요.

---

## 3. 적용한 수정 (계층별)

### 3-1. monotonic -1 보존 — 깜빡임/churn 차단

`_writeWorkingToEdge`:

```dart
final int derived = w[i][j] == -1 ? -1 : 0;
if ((origValue == -1 || origValue == -2) && derived == 0) {
  continue;   // 기존 -1/-2 는 propagation 이 재도출 못 해도 유지
}
```

- propagation 은 -1 을 추가만 하고 제거하지 않음.
- 부수 효과: -2(빨강) 자리가 propagation 결과 0 으로 덮어쓰여 사라지던 버그 동시 해결.

### 3-2. cascade-abort revert 의 surgical 화

```dart
// 변경 전
_restorePuzzleEdges(guardSnap);                   // 4 방향 edge 풀복원
submit = await readSquare.readSubmit(puzzle);

// 변경 후
await readSquare.writeSubmit(puzzle, orig);       // canonical 만 pre-propagation 으로
submit = orig;
```

- `orig` 는 `_writeWorkingToEdge` 직전의 edge 스냅샷 (사용자 탭 + chain merge + prior -1).
- inconsistent 시 새 -1 도출만 무효화, 사용자 탭/prior -1 은 유지.
- non-canonical 자리는 propagation 이 건드리지 않으므로 복원 불필요.
- helper 제거: `_snapshotPuzzleEdges`, `_restorePuzzleEdges`.

### 3-3. incremental diff (탭이 야기한 -1 만 적용)

흐름:
1. `updateSquareBox` 진입 시 (chain merge / 탭 mutation **전**) canonical submit 스냅샷 → `_preTapSubmit`.
2. `_applyConstraints` 가 `_preTapSubmit` 으로 working grid `wPre` 빌드 후 `propagateDirectSquare(wPre)` 실행 → `wPreBaseline`.
3. Post-tap 상태로 동일하게 propagation → `w`.
4. `_writeWorkingToEdge` 의 새 -1 적용 조건:

```dart
// 새 -1 마크: pre-tap propagation 으로도 도출됐을 자리는 적용 제외.
if (preBaseline != null &&
    origValue == 0 &&
    derived == -1 &&
    preBaseline[i][j] == -1) {
  continue;
}
```

- 첫 탭 시점에서도 clue + 0-clue auto-mark 만으로 도출되는 -1 은 baseline 에 포함되므로 추가되지 않고, 이번 탭이 새로 만든 -1 만 보임.
- 솔버 (`_silentMode`) 경로는 `_preTapSubmit` 무시 (전체 propagation 결과 적용).

### 3-4. proximity 보조 필터

incremental diff 만으로는 cell-rule cascade 가 멀리까지 가는 케이스 차단 부족. 사용자 라인(≥1)/X(-4) edge 로부터 graph hop 거리 BFS 계산해, 새 -1 적용 조건에 추가:

```dart
if (proximityDist != null &&
    origValue == 0 &&
    derived == -1 &&
    proximityDist[i][j] > maxProximity) {
  continue;
}
```

- `_userProximityHops = 3` (하드코딩).
- helper: `_computeUserProximity`, `_relaxNeighbor`, `_enqueueIfShorter`.

### 3-5. Phase 2 look-ahead 사용자 탭 경로 스킵

진짜 cascade 의 주범. wPreBaseline 에는 Phase 1 결과만 들어 있어 Phase 2 가 도출하는 deep -1 들이 diff 통과로 cascade.

```dart
// 변경 후
if (_silentMode && isWorkingStateConsistent(w, rows, cols, nums)) {
  // Phase 2 look-ahead 본문
}
```

- 사용자 탭: Phase 1 (cell/vertex rule fixed-point) 만.
- 솔버: Phase 1 + Phase 2 (deep deduction 보존).

### 3-6. Restart 시 자동 풀기 중단

```dart
Future<void> restart() async {
  if (_solverRunning) {
    _solverShouldStop = true;
    while (_solverRunning) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
  }
  // 기존 reset 로직 …
}
```

솔버가 wrong premise 위에서 추론 이어가지 않도록.

---

## 4. 최종 동작 요약

### 사용자 탭 경로

| 단계 | 동작 |
|------|------|
| 1 | `updateSquareBox` 진입 시 pre-tap submit 스냅샷 (chain merge 전) |
| 2 | chain merge + 탭 적용 → puzzle mutate |
| 3 | `_applyConstraints` 진입: orig = readSubmit(puzzle), w = working grid |
| 4 | wPre = pre-tap snapshot 의 working grid → `propagateDirectSquare(wPre)` → wPreBaseline |
| 5 | proximityDist = BFS from 사용자 라인/X (hop ≤ 3) |
| 6 | `propagateDirectSquare(w)` (Phase 1 만, Phase 2 스킵) |
| 7 | `_writeWorkingToEdge`: 새 -1 은 (incremental diff 통과) AND (proximity 통과) 인 자리만 적용. prior -1/-2 는 monotonic 보존 |
| 8 | inconsistent 시 canonical edge 만 orig 로 surgical revert |

### 솔버 경로 (`_silentMode == true`)

- pre-tap baseline / proximity 모두 우회.
- Phase 1 + Phase 2 + cascade-abort guard (silentMode 는 revert 안 함, 플래그만 set).
- 기존 동작 그대로.

### Restart

- 진행 중 솔버 중단 대기.
- submit/puzzle 0 초기화 + 0-clue 셀 4 변 자동 -1 마킹 (`setDefaultLineStep1`) 유지.
- doSubmit (undo/redo 스택) 초기화.

---

## 5. 변경 위치 모음 (`lib/provider/SquareProvider.dart`)

| 위치 (대략) | 내용 |
|------|------|
| `restart()` 시작 | `_solverRunning` 검사 + `_solverShouldStop` set + 대기 |
| `_silentMode` 선언 직후 | `_preTapSubmit`, `_userProximityHops` 멤버 |
| `updateSquareBox` 진입 후 | pre-tap submit 스냅샷 저장 |
| `_applyConstraints` 초반 | wPreBaseline / proximityDist 계산 |
| `_applyConstraints` Phase 2 진입 | `if (_silentMode && …)` 로 사용자 경로 스킵 |
| `_applyConstraints` 끝 | cascade-abort: `writeSubmit(puzzle, orig)` + `submit = orig` |
| `_writeWorkingToEdge` 시그니처 | `preBaseline`, `proximityDist`, `maxProximity` 옵션 추가, monotonic/diff/proximity 가드 |
| 신규 헬퍼 | `_computeUserProximity`, `_relaxNeighbor`, `_enqueueIfShorter` |
| 삭제 | `_snapshotPuzzleEdges`, `_restorePuzzleEdges` |
| `clearLineForStart` | `setDefaultLineStep1` 호출 유지 (0-clue 자동 -1) |

---

## 6. 남은 작업 (Out of Scope)

| # | 항목 | 메모 |
|---|------|------|
| A | inner cell overlay 좌표 라우팅 | SquareBox.dart 14px strip 이 non-canonical 자리를 mutate. canonical owner cell 로 라우팅 필요. |
| B | pre-tap propagation 추가 비용 (~30ms / 탭) | 대형 보드 응답성 모니터링 필요. 캐시 가능성 검토. |
| C | `_userProximityHops` 사용자 옵션화 | 현재 하드코딩 3. 난이도별 다른 값. |
| D | Phase 2 deep deduction 토글 옵션 | 사용자가 명시적으로 원할 때 사용자 탭에서도 Phase 2 사용. |

---

## 7. 참고

- `docs/constraint_lookahead.md` — propagation 규칙 (cell/vertex) 도출.
- `docs/auto_solver_bug_analysis.md` — solver / cascade-abort 의 silentMode 처리 분기 사고 분석.
- 관련 commit: `f12dcd6 Square: 탭 깜빡임 제거 + incremental diff 로 -1 시각화 한정` (이후 후속 수정은 별도 commit).
