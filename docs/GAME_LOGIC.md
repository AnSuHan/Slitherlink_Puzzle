# 게임 로직 상세 문서

## 1. 슬리더링크 규칙

각 셀의 숫자(0~4)는 해당 셀 주위에 그려야 하는 선의 수를 나타냅니다.
목표: 모든 숫자 조건을 만족하는 **단일 폐루프**를 완성하는 것.

---

## 2. 선(Line) 배치 로직

### 2.1 탭 처리

`SquareBox` 위젯의 네 방향(상/하/좌/우) 각각 탭 가능한 영역이 있습니다.
탭하면 `SquareProvider.updateSquareBox(row, col, direction)`이 호출됩니다.

### 2.2 선 상태 전환

```
탭 시 상태 순환:
빈 상태(0) → 선(1~15) → X 표시(-4) → 빈 상태(0)
```

X 표시(-4)는 "이 방향에는 선이 없다"는 것을 명시적으로 표시합니다.

### 2.3 색상 배정 규칙

새 선을 그릴 때 인접한 선들의 색상을 확인합니다:

| 상황 | 처리 |
|------|------|
| 인접 선 없음 | 랜덤 색상 (1~15) 배정 |
| 인접 선 1가지 색상 | 같은 색상 사용 |
| 인접 선 여러 색상 | 하나의 색상으로 통일 (전파) |

### 2.4 색상 전파 알고리즘

색상 충돌 발생 시 연결된 모든 선을 탐색해 색상을 통일합니다.

```
updateSquareBox(row, col, direction)
  ├─ getNearColor(row, col, direction)   ← 인접 색상 목록 수집
  ├─ 충돌 없음 → 그대로 배정
  └─ 충돌 있음
        ├─ getOldColorList(oldColor)     ← 변경 대상 선 목록 수집 (DFS)
        └─ 해당 선들 모두 newColor로 변경
```

`getContinueOld()`: 연결된 선을 재귀적으로 따라가며 같은 색상의 모든 선을 수집합니다.

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
