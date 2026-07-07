# 게임 로직 상세 문서

## 1. 슬리더링크 규칙

각 셀의 숫자(0~4)는 해당 셀 주위에 그려야 하는 선의 수를 나타냅니다.
목표: 모든 숫자 조건을 만족하는 **단일 폐루프**를 완성하는 것.

---

## 2. 선(Line) 배치 로직

> 본 절은 4종 도형(Square / Triangle / Hexagon / Trihex) 공통의 변(edge)
> 상태·탭·색상 전파를 설명한다. 시스템이 자동으로 비활성(-1)시키는
> **제약 전파(auto-disable) 규칙**의 전체 정의는 `docs/constraint_lookahead.md`
> 를 참조.

### 2.1 변 상태 값 (모든 도형 공통)

각 변은 하나의 정수로 상태를 표현한다. Square 는 `submit` 그리드에,
Triangle/Hexagon 은 셀의 `edgeN`/`edges[]` 에, Trihex 는 `edgeState[edgeId]` 맵에
저장하지만 **값의 의미는 동일**하다.

| 값 | 의미 |
|----|------|
| `0` | 미정 (빈 상태) |
| `1 ~ 15` | 사용자가 그은 선 (숫자 = chain 색상 id) |
| `-1` | 시스템이 자동 비활성화한 변 (제약 전파 결과, "여긴 절대 못 그음") |
| `-2` | 사용자가 자동 비활성(-1) 변을 탭해 "동의 안 함"으로 마킹한 변 (빨강) |
| `-3` | 힌트 — 그려야 하는 올바른 선 (깜빡임) |
| `-4` | 사용자 X 표시 ("여긴 선 없음"으로 직접 잠금) |
| `-5` | 힌트 — 잘못 그은 선 (깜빡임) |

### 2.2 탭 처리 (히트 영역)

셀의 어느 변을 탭했는지 판정하는 방식은 도형마다 다르지만, **모두 셀 면을
넉넉히 눌러도 가장 가까운 변이 선택**되도록 구현돼 있다.

| 도형 | 판정 방식 |
|------|-----------|
| Square | 셀(50×50) 전체를 두 대각선으로 4분할 → 상/하/좌/우 최근접 변. `SquareBox` 의 투명 오버레이가 `SquareProvider.updateSquareBox(row, col, {up, down, left, right})` 호출 |
| Triangle | 삼각형 면 전체 → 세 변 중 최근접 변(`pickClosestEdge`) |
| Hexagon | 육각형 면 전체 → 중심각 6분할로 최근접 변 |
| Trihex | 단일 캔버스에서 탭 지점 기준 최근접 변 midpoint (허용 반경 40px) |

### 2.3 선 상태 전환 (탭 순환)

각 위젯의 `_cycleEdge` / `_cycleEdgeValue` 가 탭 대상 변의 현재 값에 따라
다음 값을 정한다 (4종 도형 동일):

```
0  또는 -3  → 새 chain 색상 (1~15 랜덤)   // 빈 변/힌트 자리에 선 긋기
≥1 또는 -5  → -4 (X 표시)                 // 그은 선/오답힌트 → X 로
-4          → 0                           // X 해제
-1          → -2                          // 자동 비활성 변에 "동의 안 함"(빨강)
-2          → -1                          // 다시 자동 비활성으로 복귀
```

- `-1`(자동 비활성) 변을 탭하면 삭제가 아니라 `-2`(빨강)로만 마킹되고, 다시
  탭하면 `-1`로 되돌아간다. `-2`는 시각 마킹일 뿐 제약 전파의 전제가 되지
  않는다(`docs/constraint_lookahead.md` §4).
- 탭 직후 Provider 는 `updateEdge`/`updateSquareBox` → `_applyConstraints`
  로 제약 전파를 재실행해 `-1` 집합을 갱신한다.

### 2.4 색상(chain) 배정과 전파

새 선을 그릴 때 인접한 선들의 색상을 확인해 하나의 chain 으로 잇는다:

| 상황 | 처리 |
|------|------|
| 인접 선 없음 | 랜덤 색상 (1~15) 배정 |
| 인접 선 1가지 색상 | 같은 색상 사용 |
| 인접 선 여러 색상 | 하나의 색상으로 통일 (전파) |

Square 기준 흐름:

```
updateSquareBox(row, col, {up|down|left|right})
  ├─ getNearColor(row, col, dir)         ← 인접 변 색상 집합 수집
  ├─ 충돌 없음 → 그대로 배정
  ├─ 충돌 있음
  │     ├─ getOldColorList(row, col, dir, now)  ← 병합 대상 변 목록 (DFS)
  │     │     └─ getContinueOld(...)             ← 같은 색 연결 변 재귀 수집
  │     └─ 해당 변들 모두 newColor 로 통일
  └─ _applyConstraints()                 ← 제약 전파(-1 자동 비활성) 재실행
```

Triangle/Hexagon/Trihex 도 `updateEdge` 안에서 동일하게 인접 변 색을 계승·병합한다.

### 2.5 제약 자동 추론 (자동 비활성 `-1`)

라인 계산의 핵심. 사용자가 변을 그으면 시스템이 슬리더링크 규칙으로 **더 이상
그어질 수 없는 변을 `-1`로 자동 비활성화**한다. **라이브 플레이의 자동 비활성은
"사용자가 그은 변에서 직접 파생되는 것만" 계산한다**(2026-07-08 정책). 정답을
참조하지 않는다.

**라이브에서 적용되는 -1 (사용자 클릭 파생):**

| 규칙 | 발화 조건 |
|------|-----------|
| 셀 규칙 | 사용자가 그은 변 수 == 단서(num), 남은 미정 변 → -1 (그은 변이 1개 이상일 때만) |
| 꼭짓점 규칙(satisfied) | 사용자가 그은 변 2개가 한 꼭짓점에 모임 → 나머지 미정 변 -1 |

**라이브에서 끈 -1 (클릭과 무관 — 솔버 전용):**

- **look-ahead(가설 시뮬레이션):** 내가 그은 변과 무관한 먼 변까지 단서 논리로
  -1 을 도출 → 라이브에서 끔.
- **단서-only 비활성:** `num=0` 셀이 클릭 0에서 둘레 변을 자동 -1 → 끔.
- **꼭짓점 starvation**(active==0, undecided<2 → -1): 클릭 0에서 발생 → 끔.

각 Provider 의 `_liveClickDerivedOnly` 플래그로 제어한다. 규칙 전체 정의·안전
가드·도형별 자료구조 차이는 `docs/constraint_lookahead.md` 참조.

- **진입점:** 사용자 탭(`updateEdge`/`updateSquareBox`), undo/redo/restart,
  `HowToPlay`. **첫 화면(init) 및 클릭 0 상태에서는 -1 이 하나도 생기지 않는다.**
- **솔버는 예외 — 완전 추론 유지:** 자동풀기·공정성 검증(`canAutoSolve`,
  `isLogicSolvable`, on-screen 솔버)은 정답을 푸는 기능이므로 look-ahead 를 뺀
  완전한 직접 추론(단서-only 비활성 포함)을 `_propagateDirect()`(clickDerivedOnly
  기본 false)로 그대로 사용한다.
- **force-draw 는 영구 기록하지 않는다** — 가설이 "반드시 그어야 함"을 도출해도
  자동으로 선을 그어 주지 않는다(풀이 경험 보존).

---

## 3. 힌트 시스템

`SquareProvider.showHint()`

### 동작 순서

1. `checkCompletePuzzleCompletely()`로 현재 submit과 answer를 비교
2. **오답 발견** → 해당 셀에 `-5` (잘못된 선) 표시
3. **오답 없고 미완성** → 정답에 있지만 아직 그리지 않은 선에 `-3` (올바른 선) 표시
4. 힌트 선은 깜빡임 애니메이션으로 표시됨

### 힌트 초기화

다음 사용자 입력 발생 시 `removeHintLine()`이 모든 힌트 표시를 제거합니다.

---

## 4. 완성 감지

`SquareProvider.checkCompletePuzzle()`

```
1. puzzle → submit 형식으로 변환 (ReadSquare.makeSubmit)
2. submit[i][j] == answer[i][j] 전체 비교
3. 모두 일치 → 완성!
   ├─ showComplete() 다이얼로그 표시
   ├─ SharedPreferences에서 해당 퍼즐 키 삭제
   └─ progress 카운트 +1
```

---

## 5. 실행 취소 / 다시 실행 (Undo/Redo)

### 데이터 구조

```dart
List<List<List<int>>> doSubmit  // submit 스냅샷 배열
int doPointer                   // 현재 위치 (-1 = 초기 상태)
int doIndex                     // 최대 인덱스
```

### 동작

```
선 배치 후 setDo():
  doSubmit[doPointer + 1] = 현재 submit의 깊은 복사
  doPointer++
  doIndex = doPointer

undo():
  doPointer--
  submit = doSubmit[doPointer] 복원
  puzzle 재구성

redo():
  doPointer++
  submit = doSubmit[doPointer] 복원
  puzzle 재구성

undo 후 새 입력:
  doSubmit을 doPointer 이후 잘라냄
  새 상태 추가
```

---

## 6. 북마크 저장/불러오기

3가지 북마크(Red, Green, Blue)로 퍼즐 상태를 저장할 수 있습니다.

### 저장 (saveLabel)

```
SharedPreferences 저장 키:
  shape_size_progress_color        → submit 직렬화
  shape_size_progress_color_do     → undo 스택 메타데이터
  shape_size_progress_color_doValue → doPointer, doIndex
  shape_size_progress_color_doSubmit → undo 스택 데이터
```

### 불러오기 (loadLabel)

1. 저장된 submit 데이터 역직렬화
2. submit → puzzle 재구성
3. undo 스택 복원
4. UI 업데이트

---

## 7. 게임 종료 시 상태 보존 (Continue)

뒤로 가기 버튼 누를 시 `quitDoValue()`가 호출됩니다:

```
저장 키:
  shape_size_progress__doValue   → 현재 doPointer, doIndex
  shape_size_progress__doSubmit  → 전체 undo 스택
```

다음 번 "계속하기" 선택 시 이 데이터로 정확히 동일한 상태에서 재개합니다.

---

## 8. 퍼즐 좌표 시스템

### 셀 좌표 vs 선 좌표

퍼즐이 `n×m` 셀로 구성될 때:
- `puzzle[n][m]` - 셀 중심 데이터
- `submit[(2n+1)][가변]` - 모든 선 데이터

```
submit 배열 구조 (3x3 퍼즐 기준):

Row 0: [─00  ─01  ─02]           (수평선, 길이 3)
Row 1: [│00  │01  │02  │03]      (수직선, 길이 4)
Row 2: [─10  ─11  ─12]           (수평선, 길이 3)
Row 3: [│10  │11  │12  │13]      (수직선, 길이 4)
Row 4: [─20  ─21  ─22]
Row 5: [│20  │21  │22  │23]
Row 6: [─30  ─31  ─32]
```

홀수 행 = 수직선 (셀 수 + 1개)
짝수 행 = 수평선 (셀 수개)

### 변환 함수

- `ReadSquare.makeSubmit(puzzle)` → puzzle을 submit 형식으로 변환
- `ReadSquare.makePuzzle(submit)` → submit을 puzzle로 복원
- `SquareProvider.setLineColor(row, col, dir, color)` → submit에 색상 기록
- `SquareProvider.getLineColor(row, col, dir)` → submit에서 색상 읽기

---

## 9. 정답 데이터 형식

`Answer/Square_small.json`:
- 1410개의 퍼즐 정답 포함
- 각 정답: 10행 × 20열 boolean 배열
- `true` = 선 있음, `false` = 선 없음
- submit 형식과 동일한 구조로 변환하여 비교

```json
[
  [false, true, true, false, ...],  // row 0
  [true, false, true, true, ...],   // row 1
  ...
]
```

---

## 10. 디버그 모드

`Answer.dart`에 개발용 기능이 포함되어 있습니다:

| 기능 | 함수 | 설명 |
|------|------|------|
| 사이클 검증 | `checkCycleSquare()` | DFS로 단일 루프 확인 |
| 중복 감지 | `checkDuplicate()` | 동일 패턴 퍼즐 탐지 |
| 키 입력 | `KeyInput` | A=정답표시, F=강제완성, P=출력 |
