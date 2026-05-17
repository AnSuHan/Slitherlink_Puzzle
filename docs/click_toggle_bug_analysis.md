# 클릭 시 보드 전체 상태가 토글되는 버그 분석

작성일: 2026-05-17
대상 브랜치: `puzzleType`

## 사용자 보고

> 이 두 상태가 클릭할 때마다 왔다갔다 한다, 누른 선에 영향을 받는 부분만 선 변경이 되어야 한다.

- 두 개의 시각 상태가 클릭마다 교대로 나타남
- 기대 동작: 누른 선과 그 인접부만 갱신
- 실제 동작: 보드 전체의 dim(-1) 분포가 한꺼번에 바뀜

## 원인 (가능성 순)

### 1. cascade-abort 전면 복원 (가장 강한 영향)

`lib/provider/SquareProvider.dart` 1812-1822:

```dart
if (!isWorkingStateConsistent(liveW, rows, cols, nums)) {
  if (_silentMode) {
    _solverDetectedInconsistency = true;
    submit = edge;
  } else {
    _restorePuzzleEdges(guardSnap);                 // ← 전면 복원
    submit = await readSquare.readSubmit(puzzle);
  }
} else {
  submit = edge;                                    // ← 새 -1 적용
}
```

- guardSnap: `_applyConstraints` 진입 시점에 puzzle 전체 4 방향 edge 풀스냅샷 (1709 line).
- 사용자 탭이 propagation 일관성 체크에 통과하면 → 새 -1 분포 적용 (`submit = edge`).
- 통과 못 하면 → `_restorePuzzleEdges`로 보드 전체 복원 → 이전 -1 분포 유지.

**토글 메커니즘:**
사용자가 같은 위치를 cycle (예: 0 → color → -4 → 0) 하면 입력값이 달라지는데, 일부 값에서는 propagation 일관성 OK 일부에서는 NG. 결과적으로:
- consistent 클릭 → 새 -1 분포 D_new (보드 전체에 분산)
- inconsistent 클릭 → 이전 -1 분포 D_old (guardSnap 복원)

두 분포가 다르므로 보드 전체가 교대로 다른 모양을 띄게 됨.

### 2. `_writeWorkingToEdge` 의 -1 전면 재계산

`lib/provider/SquareProvider.dart` 1828-1844, working grid 빌드 1719-1723:

```dart
final List<List<int>> w = edge.map((row) => row.map((v) {
  if (v >= 1) return 1;
  if (v == 0 || v == -1 || v == -2) return 0;   // 기존 -1 → 0
  return -1;
}).toList()).toList();
```

- 매 탭마다 working grid 빌드 시 기존 -1/-2 를 0(undecided)으로 매핑.
- propagation 이 처음부터 다시 전 보드의 -1 을 도출.
- `_writeWorkingToEdge` 가 그 결과를 edge 에 그대로 반영하면서 이전 -1 자리가 새 derivation 으로 대체.

**구조적 한계:**
"누른 선 주변만 변경" 이 불가능. propagator 가 incremental 이 아니라 매 탭마다 사용자의 ≥1 라인만을 premise 로 전 보드를 처음부터 다시 계산.

### 3. inner-cell 의 box-overlay tap 좌표 어긋남

`lib/widgets/SquareBox.dart` 343-370:

```dart
Positioned(
  left: 0, top: 0, bottom: 0, width: 14,
  child: GestureDetector(
    behavior: HitTestBehavior.translucent,
    onTap: () => _tapEdgeFromOverlay("left"),
  ),
),
// ... top/right/bottom 동일
```

- 각 박스 면 내부 14px strip 4 개가 line tap zone 을 넓힘.
- `_tapEdgeFromOverlay("left")` → `widget.left` cycle 후 `updateSquareBox(row, col, left: ...)` 호출.
- 이때 puzzle[r][c].left 가 mutate 됨.

**문제:**
inner cell (i ≥ 1, j ≥ 1) 에서 `.left`/`.up` 은 canonical edge 저장 위치가 아님. canonical 은 `puzzle[r][c-1].right` / `puzzle[r-1][c].down`.

`lib/MakePuzzle/ReadSquare.dart` 122-210:

```dart
// inner cell: down, right 만 round-trip
if (i != 0 && j != 0) {
  lineData[(i + 1) * 2][j] = puzzle[i][j].down;
  lineData[(i * 2) + 1][j + 1] = puzzle[i][j].right;
}
```

- `readSubmit` 은 inner cell 의 .left/.up 을 무시.
- `writeSubmit` 은 .down/.right 만 덮어씀.

**결과:**
- 누른 자리 자체 (.left of inner cell) 는 propagation 에 안 들어감.
- `updateSquareBox` 의 chain merge (`getOldColorList`) 는 canonical 이웃에 작용 → 누른 자리에서 떨어진 위치의 색이 바뀜.

## 1번 항목 수정 (적용 완료, 2026-05-17)

### 적용한 변경

`lib/provider/SquareProvider.dart`

1) `_writeWorkingToEdge` 에 monotonic 보존 추가:

```dart
final int derived = w[i][j] == -1 ? -1 : 0;
if ((origValue == -1 || origValue == -2) && derived == 0) {
  continue;  // 기존 -1/-2 는 propagation 이 재도출 못 해도 유지
}
edge[i][j] = (origValue == -2 && derived == -1) ? -2 : derived;
```

- propagation 은 -1 을 추가만 하고 제거하지 않음 (monotonic).
- 매 탭마다 보드 전체 -1 분포가 churn 되던 부분 제거.
- 부수 효과: -2(빨강) 자리가 propagation 결과 0 으로 덮어쓰여 사라지던 버그 동시 해결.

2) cascade-abort revert 를 canonical 한정 surgical 복원으로 변경:

```dart
// 변경 전
_restorePuzzleEdges(guardSnap);
submit = await readSquare.readSubmit(puzzle);

// 변경 후
await readSquare.writeSubmit(puzzle, orig);
submit = orig;
```

- `orig` 는 `_writeWorkingToEdge` 직전의 edge 스냅샷 (사용자 탭 + chain merge + prior -1 포함).
- propagation 이 모순 결과를 만들면 canonical edge 만 orig 로 복원 → 새 -1 만 사라지고 사용자 탭과 prior -1 유지.
- non-canonical 자리 (inner cell .left/.up) 는 propagation 이 건드리지 않으므로 복원할 것 없음.

3) 사용되지 않게 된 helper 제거: `_snapshotPuzzleEdges`, `_restorePuzzleEdges`.

### 사용자 검증

> 깜빡거림은 사라졌어 (2026-05-17 사용자 보고)

토글 동작이 더 이상 관찰되지 않음.

## 2번 항목 (1차 시도 → 폐기 → 재설계)

### 사용자 추가 보고

> 처음 상태에서 라인 하나 클릭하면 많은 라인이 바로 비활성화 되는데, 이 문제를 해결해

깜빡임은 해결됐으나, 첫 탭 한 번에 propagator 가 clue-only 도출 가능한 모든 -1 을 한꺼번에 보드 전체에 뿌리는 것이 너무 강해 보임.

### 1차 시도: graph 거리 BFS proximity (폐기됨)

사용자 라인(≥1)/X(-4) canonical edge 로부터 BFS hop ≤ 2 인 자리에만 새 -1 적용.

문제: 사용자가 원하는 건 graph 거리 기준이 아니라 **인과 관계**. clue 만으로도 도출됐을 -1 은 graph 거리와 무관하게 보지 않으려 함. 사용자 보고 "아직도 똑같은 문제 발생함" 으로 폐기.

### 2차 시도: incremental diff (적용)

사용자 명시:
> -1은 사용 필요해. 누른 선에 대한 -1만 보여야 해, 아니면 0으로 보여야 하고

= "이 탭이 야기한 -1 만 시각화, 그 외는 0".

#### 구조

1) `updateSquareBox` 진입 시점에 canonical submit 스냅샷 `_preTapSubmit` 저장 (chain merge / 탭 mutation 전).
2) `_applyConstraints` 에서 pre-tap 상태로 working grid `wPre` 빌드 후 `propagateDirectSquare(wPre)` 실행 → `wPreBaseline`.
3) Post-tap 상태로 동일하게 propagation → `w`.
4) `_writeWorkingToEdge` 의 새 -1 적용 조건에 다음 추가:
   - origValue == 0 && derived == -1 && wPreBaseline[i][j] == -1 인 경우 적용 안 함.
   - 즉 pre-tap propagation 으로도 도출됐을 -1 은 "이 탭이 야기한 것이 아님" 이므로 0 유지.

#### 결과

- 첫 탭 from initial state: clue 만으로 derive 되는 -1 은 wPreBaseline 에도 있으므로 적용 제외. 이번 탭 자체가 만든 chain rule 결과만 visible.
- 두 번째 탭부터: prior 탭의 -1 은 monotonic 으로 puzzle 에 이미 존재. 새 탭은 그 위에 자기 effect 만 얹음.
- 솔버 (_silentMode): _preTapSubmit 무시, 기존처럼 전체 propagation 결과 적용.

#### 폐기된 헬퍼

`_computeUserProximity`, `_relaxNeighbor`, `_enqueueIfShorter`, `_userProximityHops` 상수 — 모두 삭제. proximity 방식이 더 이상 사용되지 않음.

### 후속 수정 (보류 → 복원)

사용자 보고 (2026-05-17):
> 하나 클릭했는데 필드 왼쪽 아래가 비활성화 되는 이유가 뭐냐고, 저기까지 이벤트가 넘어가면 안 된다.

1차 해석: `setDefaultLineStep1` 의 자동 -1 마킹이 원인 → 호출 제거.

사용자 재보고:
> restart를 하니 0인 박스의 주변도 라인0으로 잘못 표기되는 문제가 발생했어.

= 0-clue 셀 4 변의 자동 -1 마킹은 직접 의미 (no edges) 라 필요. 제거하면 안 됨.

최종 결정:
- `clearLineForStart` 의 `setDefaultLineStep1` 호출 **복원**.
- 0-clue 자동 -1 은 시작부터 표시.
- 그 이상의 -1 (propagation 도출분) 은 incremental diff 로 사용자 탭이 야기한 것만 추가.
- 첫 탭 시점에서도 wPreBaseline 이 clue + 0-clue auto-mark 만으로도 도출되는 -1 을 모두 포함하므로 그것은 새로 추가되지 않고, 이번 탭이 새로 만든 -1 만 보임.

## 미해결 (다음 단계 후보)

- 3번: inner cell overlay 의 좌표를 canonical owner cell 로 라우팅 (SquareBox 와 provider 양쪽 작업).
- pre-tap propagation 이 매 탭마다 추가 비용 (~30ms). 응답성 영향 모니터링 필요.
