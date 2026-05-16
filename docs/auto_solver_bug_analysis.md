# Auto Solver 오작동 원인 분석

증상: "사람처럼 풀기 (auto solve)" 메뉴 실행 시 사용자가 의도하지 않은 위치에
자동 비활성화(-1) 가 누적되고, 솔버가 진행할수록 보드 전체에 어긋난 disable 이
퍼진다.

조사 대상 코드:
- `lib/provider/square_propagation_core.dart` (propagation 및 솔버 보조 함수)
- `lib/provider/SquareProvider.dart` (`solveHumanLike`, `_solverApplyDraw`,
  `_applyConstraints` 등)

코드 수정 없이 흐름 추적 결과만 정리한다.

---

## 1. 1차 (확정) 원인 — `pickHighestImpactGuess` 의 의미 충돌

**위치**: `square_propagation_core.dart:486-511`

```dart
List<int>? pickHighestImpactGuess(...) {
  ...
  w[er][ec] = 1;
  final bool contradiction =
      propagateHypothesisSquare(w, rows, cols, nums, changes: hypChanges);
  final int score = contradiction ? 1 << 20 : hypChanges.length;
  ...
}
```

함수 의도: "현재 보드에서 undecided edge 중 가설(=1) 을 세웠을 때 가장 많은
propagation 을 일으키는 edge 를 골라 추측 후보로 반환한다."

문제: `contradiction == true` 인 edge 의 score 를 1<<20 (= 1,048,576) 으로 두어
무조건 1위 가 되도록 한다. 이때 의미는:

| hypothesis | propagation 결과 | 논리적 의미 |
|------------|------------------|-------------|
| edge = 1   | 일관             | 그릴 수도, 안 그릴 수도 있음 → 추측 후보 |
| edge = 1   | **모순**         | edge 는 절대 +1 이 될 수 없음 → **반드시 -1** |

즉 contradiction 인 edge 는 "추측" 이 아니라 **"확정 -1"** 이다. 그런데 함수가
가장 높은 score 로 이 edge 를 반환하면, 호출자 (솔버) 는 이를 "추측해 그릴
대상" 으로 받아 그어버린다.

**호출자 동작**: `SquareProvider.solveHumanLike`

```dart
final List<int>? guess = pickHighestImpactGuess(w, rows, cols, nums);
...
await _solverApplyDraw(guess[0], guess[1]); // 양수 1 을 보내 chain color 로 +1 그리기
```

`_solverApplyDraw` 는 `updateSquareBox(row, col, dir: 1)` 을 호출 → 양수 분기에서
`getNormalRandom()` 또는 `nearColor.first` 로 색을 골라 puzzle 에 그린다.

결과: **반드시 -1 이 되어야 할 edge 를 +1 로 그리는** 잘못된 첫 수가 보드에
박힌다. 이후 propagation 은 이 wrong premise 를 진실로 받아들이고 그 주변에
정합적인 -1 들을 도출 → 사용자 입장에서는 "내가 클릭한 적 없는 edge 가 그려져
있고 그 주변에 disable 이 흩뿌려져 있는" 보드가 보인다.

### 1.1 왜 `findForcedDrawByContradiction` 만으로는 안 막히나

`findForcedDrawByContradiction` (line 458) 은 "edge=-1 가설 → 모순 → 반드시 +1" 만
검출한다. 즉 +1 확정만 잡는 함수이고, "edge=+1 가설 → 모순 → 반드시 -1" 인 -1
확정은 솔버 루프에 따로 잡는 단계가 없다.

`_applyConstraints` 의 Phase 2 look-ahead 가 이 -1 확정을 어느 정도 잡지만,
`for (int laIter = 0; laIter < 2; laIter++)` 로 2 회 outer 제한이 걸려 있어 깊은
체인 deduction 은 누락된다. 솔버 루프에서 누락분이 `pickHighestImpactGuess` 까지
살아남았을 때 위 1번 의 contradiction-as-guess 버그가 트리거된다.

---

## 2. 2차 원인 — `_applyConstraints` 의 cascade-abort 가 솔버 backtracking 에 부적합

**위치**: `SquareProvider._applyConstraints`

```dart
final List<List<List<int>>> guardSnap = _snapshotPuzzleEdges();
// ... Phase 1 propagation, writeSubmit ...
// ... Phase 2 look-ahead ...
if (!isWorkingStateConsistent(liveW, rows, cols, nums)) {
  _restorePuzzleEdges(guardSnap);
  submit = await readSquare.readSubmit(puzzle);
}
```

`guardSnap` 의 스냅 시점이 **`updateSquareBox` 가 새 라인을 puzzle 에 박은 뒤**,
`_applyConstraints` 진입 시점이다. 따라서 cascade-abort 가 발동하면:

- puzzle 은 "라인 그어진 상태 + propagation -1 없음" 으로 돌아간다.
- **라인 자체는 지워지지 않는다.**

솔버는 다음 iter 진입 시 `submit = readSubmit(puzzle)` 를 다시 읽고
`propagateDirectSquare(w)` 를 돌리는데, 이 시점에 puzzle 에는 잘못 그어진 라인이
그대로 남아있다. 직접규칙으로 즉시 모순이 잡히지 않는 한 (잘못된 +1 이 어떤
clue 를 overdraw 하지 않는 한) `isWorkingStateConsistent(w)` 는 통과한다.

**결론**: cascade-abort 는 사용자 1회 탭의 "확실히 깬 경우" 만 안전망 역할을
하도록 설계된 것이고, 잘못된 가설에 대한 솔버 backtracking 신호로는 부족하다.
솔버는 cascade-abort 가 일어났는지/`guardSnap` 으로 revert 되었는지 자체적으로
탐지할 수 없다.

---

## 3. 3차 원인 — 솔버의 backtracking 트리거 부족

**위치**: `SquareProvider.solveHumanLike`

```dart
final List<List<int>> w = buildWorkingFromEdges(submit);
propagateDirectSquare(w, rows, cols, nums);

if (!isWorkingStateConsistent(w, rows, cols, nums)) {
  // backtrack via guess stack
  ...
}
```

backtracking 은 오직 직접규칙 + 사후 일관성 검사에서 모순이 검출될 때만 발동.
1·2 절에서 본 것처럼 잘못 그어진 라인이 직접규칙으로 즉시 모순을 만들지 않으면
검사를 통과하고, 솔버는 그 위에서 다음 forced-draw 를 찾는다. 이때 forced
inference 는 잘못된 premise 에 기반해 또 잘못된 +1 을 도출할 수 있고, 전체적인
빗나간 disable 패턴이 누적된다.

`findForcedDrawByContradiction` 자체는 정직하지만, 그 입력 `w` 가 이미 wrong
premise 를 포함하고 있으면 "정직하게 잘못된 결과" 를 내놓는다.

---

## 4. 부수적으로 관찰된 사항

### 4.1 `findForcedDrawByContradiction` 의 결정성

함수는 발견한 **첫 번째** forced +1 만 반환한다(스캔 순서: (0,0) → (0,1) → ...).
틀린 inference 는 아니지만, 사람처럼 "체인을 따라가는" 시각과 어긋나 — 사용자
에게는 보드 임의 위치에서 라인이 튀어나오는 것처럼 보인다. 깜빡임 보고와
별개의 UX 문제이지만 "사람처럼" 이라는 요구 사항에 대한 격차로 기록해 둔다.

### 4.2 `pickHighestImpactGuess` 의 비용

가설 propagation 을 모든 undecided edge 에 대해 1 회씩 수행한다 — 16×16 보드
에서 약 500 개 edge × 평균 propagation ~5ms = 2.5 초. 솔버가 막힐 때마다 한 번씩
수행되고, 사이사이 500ms 시각 지연이 더해져 사용자가 "느리다" 고 느낄 수 있다.

### 4.3 `_silentMode` Phase 1 skip 시도의 흔적

이전 디버깅에서 `_silentMode` 인 동안 Phase 1 의 writeSubmit 을 생략하는 시도가
있었다. 이 변경은 본 분석 직전 revert 되었으므로 현재 코드에는 남아 있지 않지만,
당시 발생한 부수 버그(`laAnyChanged == false` 인 클릭에서 Phase 1 결과가 puzzle
에 영원히 안 써져 다음 step 의 propagation 입력이 어긋남) 도 같은 류의 "wrong
premise 누적" 문제를 만든다. 향후 비슷한 최적화 시 주의.

---

## 5. 수정 방향 (참고만 — 본 문서에서는 적용 안 함)

1. **`pickHighestImpactGuess` 가 contradiction edge 를 추측 후보로 반환하지 않게**:
   contradiction 이 발견되면 그 edge 는 "forced -1" 로 분류해 솔버에 반환 형식을
   분리한다 (예: `(kind: forced_disable | forced_draw | guess, r, c)`).

2. **솔버 루프에 "+1 가설 → 모순 → -1 확정" 단계 추가**: `findForcedDrawByContradiction`
   다음에 `findForcedDisableByContradiction` (가칭) 을 두고, 두 가지 forced
   inference 를 모두 소진한 다음에야 guess 단계로 진입.

3. **솔버 전용 propagation 파이프라인**: `_applyConstraints` 의 cascade-abort 가
   guardSnap (post-draw) 으로만 revert 하는 것을 솔버가 우회. 솔버는 in-memory
   working grid 에서 모든 가설을 검증한 뒤 puzzle 에 commit 하고, 모순이 검출되면
   commit 하지 않고 backtracking 으로 바로 전환.

4. **체인 친화적 forced-draw 선택**: 여러 forced +1 중에서 가장 최근 그린 라인에
   인접한 것을 우선 선택해 "체인을 따라간다" 는 인상을 준다.

본 문서는 분석 전용이며, 위 수정은 별도 task 에서 진행한다.
