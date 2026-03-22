# Flutter 앱 현재 상태 분석

> 분석 대상: `Slither_Project/lib/` 전체

---

## 1. 퍼즐 데이터 구조

### 1.1 이중 표현 방식

퍼즐 데이터는 두 가지 형태로 동시에 관리됩니다:

**SquareBox (UI 렌더링 단위):**
```dart
class SquareBox {
  int up, down, left, right;  // 각 방향의 라인 상태 값
  int num;                     // 셀 힌트 숫자
  int boxColor;                // 셀 강조 여부 (0: 일반, 1: 강조)
}
```

**submit/answer (검증용 확장 그리드):**
- 크기: `(2*rows+1)` 행
  - **짝수 행**: 수평 엣지 (`cols`개)
  - **홀수 행**: 수직 엣지 (`cols+1`개)
- 예시 (10×10 퍼즐): `21행 × 20~21열`

### 1.2 라인 상태 값 의미

| 값 | 의미 | 표시 |
|----|------|------|
| `0` | 미선택 (기본값) | 회색 선 |
| `1~15` | 선택됨 (색상 번호) | 테마 색상 선 |
| `-1` | 비활성 미선택 | 연한 회색 |
| `-2` | 비활성 선택 | 분홍색 |
| `-3` | 정답 힌트 | 파란↔노란 깜빡임 |
| `-4` | 사용자 X 표시 | 검정 X 아이콘 |
| `-5` | 오답 힌트 | 검정↔빨강 깜빡임 |

### 1.3 좌표 변환 (SquareBox ↔ submit 배열)

```
puzzle[row][col].up    → submit[row*2][col]
puzzle[row][col].down  → submit[row*2+2][col]
puzzle[row][col].left  → submit[row*2+1][col]
puzzle[row][col].right → submit[row*2+1][col+1]
```

---

## 2. 퍼즐 데이터 로딩 방식

### 2.1 데이터 소스: 로컬 번들 JSON

```
lib/Answer/Square_small.json  (앱 번들에 포함)
       ↓ rootBundle.loadString()
Answer.dart (초기화 시 전체 로드)
       ↓ squareSmallAnswer: List<List<bool>>
ReadSquare.dart (퍼즐 선택 시 개별 로드)
       ↓
SquareProvider (게임 상태 관리)
```

### 2.2 JSON 데이터 포맷

```json
{
  "square_small_00": [
    [0, 0, 1, 0, 1, 1, ...],   // 수평 엣지 행 (cols개)
    [0, 0, 1, 1, 1, 0, 1, ...], // 수직 엣지 행 (cols+1개)
    ...
  ],
  "square_small_01": [ ... ],
  "square_small_test": [ ... ]
}
```

**키 명명 규칙:** `{type}_{size}_{index}` (예: `square_small_00`)

**값 의미:** `1` = 라인 있음, `0` = 라인 없음

**데이터 변환:** `1 → true`, `0 → false` → 이후 `true → 1`, `false → 0`으로 역변환

### 2.3 진행 상황 저장 (SharedPreferences)

| 키 패턴 | 저장 내용 |
|---------|---------|
| `square_small_0_continue` | 현재 진행 상황 (List<List<int>>) |
| `square_small_0_Red` | 북마크 저장 (색상명으로 구분) |
| `square_small_0_Red_do` | 북마크의 Undo/Redo 히스토리 |
| `square_small_0__doSubmit` | 현재 플레이 히스토리 |
| `square_small_0_doValue` | 히스토리 포인터 및 상태 |

---

## 3. 정답 검증 로직 (Answer.dart)

### 3.1 기본 비교 (SquareProvider.checkCompletePuzzle)

```dart
// submit과 answer를 직접 비교
for (각 라인) {
  if (submit[i][j] != answer[i][j]) return;  // 불일치 → 미완성
}
// 모두 일치 → 퍼즐 완성!
```

### 3.2 완전한 오류 검사 (checkCompletePuzzleCompletely, 힌트 제공용)

```dart
List<List<dynamic>> result = [];  // [row, col, dir, isWrongSubmit]

// 1단계: 오류 감지 (잘못 그은 라인)
if (submit[i][j] >= 1 && answer[i][j] == 0)  // 있으면 안 되는데 그음
    result.add([row, col, dir, true]);
if (submit[i][j] == -4 && answer[i][j] == 1)  // X 표시했는데 실제 정답
    result.add([row, col, dir, true]);

// 2단계: 오류가 없으면 미입력 정답 탐색
if (result.isEmpty) {
  if (submit[i][j] == 0 && answer[i][j] == 1)  // 안 그었는데 그어야 함
    result.add([row, col, dir, false]);
}
```

### 3.3 사이클 검사 (checkCycleSquare, 디버그 전용)

**알고리즘:** DFS 기반 사이클 탐지

```dart
// 짝수 행 (수평선) 인접 방향
evenDirections = [[-1,0], [-1,1], [1,0], [1,1], [0,-1], [0,1]];

// 홀수 행 (수직선) 인접 방향
oddDirections = [[-2,0], [2,0], [-1,-1], [1,-1], [-1,0], [1,0]];

// 부모 노드가 아닌 다른 방문 노드를 만나면 사이클 판정
```

> **주의:** 사이클 존재 여부만 확인, "정확히 하나의 폐루프"인지는 검증하지 않음

### 3.4 중복 검사 (checkDuplicate, 디버그 전용)

모든 퍼즐 쌍에 대해 `calculateMatchPercentage()`로 유사도(%) 계산

---

## 4. SquareProvider 상태 관리

### 4.1 핵심 상태

```dart
List<List<SquareBox>> puzzle;     // UI 렌더링용
List<Widget> squareField;         // 빌드된 위젯 트리
List<List<int>> answer;           // 정답 데이터
List<List<int>> submit;           // 현재 사용자 입력
int _isUpdating = 0;              // 동시성 제어
```

### 4.2 주요 메서드

| 메서드 | 기능 |
|--------|------|
| `init()` | 퍼즐 초기화 및 위젯 트리 구성 |
| `updateSquareBox(row, col, ...)` | 라인 상태 업데이트 (색상 자동 결정) |
| `setLineColor(row, col, color)` | 직접 색상 지정 |
| `refreshSubmit()` | submit 배열 재계산 |
| `checkCompletePuzzle(context)` | 완성 검사 |
| `showHint(context)` | 랜덤 힌트 제공 |
| `undo()` / `redo()` | 되돌리기/다시하기 |
| `loadLabel(submit)` | 북마크 상태 복원 |

### 4.3 라인 색상 자동 결정 로직

```
1. 주변에 색상 있는 라인 없음 → 랜덤 색상 (1~15) 부여
2. 주변에 색상 있는 라인 있음 → 인접 색상 선택 (연결선 병합)
   - 다른 색상의 기존 라인들도 모두 같은 색상으로 변경
```

### 4.4 Undo/Redo 메커니즘

```dart
List<List<List<int>>> doSubmit = [];  // 히스토리 스택
int doPointer = -1;                   // 현재 위치
int doIndex   = -1;                   // 최대 유효 인덱스

// Undo 후 새 작업 시 이후 히스토리 삭제 (분기 방지)
```

### 4.5 동시성 제어 (_isUpdating)

```
0: 업데이트 가능
1: updateSquareBox 실행 중
2: setDo 준비 중
3: setDo 실행 중
```

---

## 5. GameSceneSquare 렌더링

```
GameSceneSquare (StatefulWidget)
  └─ Consumer<SquareProvider>
       └─ InteractiveViewer (핀치 확대/축소)
            └─ Column
                 └─ squareField (List<Widget>)
                      └─ [SquareBox 위젯들]
```

### 5.1 SquareBox 위젯 구조 (각 셀)

각 셀은 **9개 터치 영역**으로 구성:

```
    [위 라인 GestureDetector]
[좌] [셀 중앙 (힌트 숫자)] [우]
    [아래 라인 GestureDetector]
```

- **코너 점**: 5×5 회색 원
- **라인**: 상태 값에 따라 색상/아이콘 결정

### 5.2 라인 색상 렌더링 규칙

| 값 | 에셋/스타일 |
|----|-----------|
| `0` | `line_normal` (회색) |
| `1~15` | `line_01` ~ `line_15` (테마 색상) |
| `-1` | `line_disable` (연한 회색) |
| `-2` | `line_wrong` (분홍) |
| `-3` | 파랑↔노랑 깜빡임 애니메이션 |
| `-4` | `line_x` (검정 X 아이콘) |
| `-5` | 검정↔빨강 깜빡임 애니메이션 |

---

## 6. 퍼즐 생성 기능 현황

**결론: 퍼즐 생성 기능 없음**

| 항목 | 현재 상태 |
|------|---------|
| 퍼즐 생성 알고리즘 | 없음 |
| 지원 그리드 타입 | Square만 |
| 지원 크기 | small (10×10)만 |
| 데이터 소스 | 하드코딩된 JSON 파일만 |
| 난이도 개념 | 없음 (JSON에 고정값) |
| 유일해 보장 | 없음 |

`MakePuzzle/` 디렉토리의 `ReadPuzzleData.dart`, `ReadSquare.dart`는 **생성이 아닌 로딩만** 담당.

---

## 7. 전체 게임 플로우

```
MainUI
  ├─ 퍼즐 선택 (type + size)
  └─ GameSceneSquare 이동
       ├─ Answer.initPuzzleAll() (JSON → squareSmallAnswer)
       ├─ ReadSquare.loadPuzzle() (answer + submit 초기화)
       ├─ SquareProvider.init() (위젯 트리 구성)
       │
       ├─ [플레이]
       │   ├─ SquareBox 터치 → updateSquareBox()
       │   ├─ setDo() → 히스토리 기록
       │   └─ checkCompletePuzzle() → 완성 판정
       │
       └─ [종료]
           └─ SharedPreferences에 진행 상황 저장
```

---

## 8. 디버그 기능 (MainUI.debugMode)

| 플래그 | 기능 |
|--------|------|
| `loadTestAnswer` | 테스트 퍼즐만 로드 |
| `enable_extract` | 데이터 추출 버튼 표시 |
| `use_KeyInput` | 키보드 단축키 활성화 |
| `Answer_showCycle` | 사이클 감지 실행 |
| `print_isUpdating` | 동시성 상태 로깅 |
| `print_methodName` | 메서드 호출 로깅 |

---

## 9. 현재 앱의 한계

1. **고정된 퍼즐**: 동적 생성 불가, JSON 내 퍼즐만 플레이 가능
2. **고정된 크기**: 10×10(small)만 지원
3. **단일 타입**: Square 격자만 지원 (Hex/Tri 없음)
4. **불완전한 규칙 검증**: 사이클 존재 여부만 확인, 단일 루프 여부 미검증
5. **난이도 없음**: 힌트 숫자 수는 JSON에 고정
