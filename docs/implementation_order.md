# 적용 순서 문서

> Java 퍼즐 생성기를 Flutter 앱에 통합하는 단계별 구현 순서
> 각 단계는 이전 단계 완료 후 진행 (의존 관계 있음)

---

## 전체 흐름 개요

```
[1단계] 데이터 클래스 정의
    ↓
[2단계] 퍼즐 생성 알고리즘 포팅 (독립 모듈)
    ↓
[3단계] 포맷 변환 레이어 구현
    ↓
[4단계] 기존 로딩 로직에 생성 옵션 추가
    ↓
[5단계] 정답 검증 로직 개선
    ↓
[6단계] Provider 및 게임 씬 연결
    ↓
[7단계] UI 개선 (난이도·크기 선택)
    ↓
[8단계] 테스트 및 검증
```

---

## 1단계 — 데이터 클래스 정의

**새 파일:** `lib/PuzzleGeneration/slitherlink_puzzle.dart`

구현 내용:
- `SlitherlinkPuzzle` 데이터 클래스
  - `int rows, cols`
  - `List<List<int>> clue` (힌트, -1 = 비공개)
  - `List<List<int>> solution` (정답 숫자)
  - `List<List<bool>> hEdge` (수평 엣지)
  - `List<List<bool>> vEdge` (수직 엣지)
- `SlitherlinkDifficulty` 열거형
  ```dart
  enum SlitherlinkDifficulty {
    easy(0.80), normal(0.55), hard(0.35);
    final double hintRatio;
    const SlitherlinkDifficulty(this.hintRatio);
  }
  ```

**의존:** 없음

---

## 2단계 — 퍼즐 생성 알고리즘 포팅

**새 파일:** `lib/PuzzleGeneration/slitherlink_generator.dart`

구현 순서 (함수 단위):

### 2-1. 엣지 인코딩 유틸리티
```dart
// 두 노드 ID → 단일 키 (비트 시프트, 노드 수 ≤ 65535)
int encodeEdge(int a, int b) => (min(a, b) << 16) | max(a, b);
```

### 2-2. 인접 노드 목록 계산
```dart
List<int> getNeighbors(int node, int nodeRows, int nodeCols)
// 상/하/좌/우 4방향, 격자 경계 처리 포함
```

### 2-3. `generateLoop()` — Wilson's LERW
```dart
// path(List) + pathSet(Set) + positionMap(Map) 조합
// path.indexOf → positionMap[next]으로 O(1) 조회 (Java 대비 최적화)
// 최대 totalNodes × 10 스텝, 실패 시 null 반환
```

### 2-4. `isValidLoop()` — 유효성 검증
```dart
// 조건 1: 엣지 수 ≥ 4
// 조건 2: 모든 활성 노드의 차수 = 2
// 조건 3: BFS로 단일 연결 성분 확인
// Queue<int> 사용 (dart:collection)
```

### 2-5. `computeSolution()` — 정답 숫자 계산
```dart
// solution[r][c] = hEdge[r][c] + hEdge[r+1][c] + vEdge[r][c] + vEdge[r][c+1]
```

### 2-6. `buildClue()` — 힌트 배치
```dart
// Fisher-Yates 부분 셔플 (O(k), k = 공개 셀 수)
// difficulty.hintRatio 적용
```

### 2-7. `generate()` — 최상위 진입점
```dart
SlitherlinkPuzzle generate(int rows, int cols, SlitherlinkDifficulty difficulty, {int? seed})
// generateLoop 최대 100회 재시도
// 성공 시 SlitherlinkPuzzle 반환
```

**의존:** 1단계 완료

---

## 3단계 — 포맷 변환 레이어 구현

**새 파일:** `lib/PuzzleGeneration/puzzle_format_converter.dart`

> 이 단계가 없으면 생성기 출력을 기존 Flutter 코드에 연결할 수 없음

### 3-1. 생성기 출력 → Flutter answer 배열 변환
```dart
List<List<int>> toFlutterAnswer(SlitherlinkPuzzle puzzle) {
    // hEdge[r][c] = true  →  answer[r*2][c]   = 1  (짝수 행 = 수평 엣지)
    // vEdge[r][c] = true  →  answer[r*2+1][c] = 1  (홀수 행 = 수직 엣지)
}
```

### 3-2. 생성기 clue → Flutter 힌트 숫자 배열 변환
```dart
List<List<int>> toFlutterClue(SlitherlinkPuzzle puzzle)
// clue[r][c] 값 그대로 전달 (-1 = 숨김, 0~4 = 힌트)
// 기존 SquareBox.num 필드에 연결
```

### 3-3. (역방향) Flutter answer 배열 → hEdge/vEdge 변환
```dart
SlitherlinkPuzzle fromFlutterAnswer(List<List<int>> answer, int rows, int cols)
// 기존 JSON 퍼즐도 검증에 사용 가능하도록
```

**의존:** 1단계, 2단계 완료

---

## 4단계 — 기존 로딩 로직에 생성 옵션 추가

**수정 파일:** `lib/MakePuzzle/ReadSquare.dart`

변경 내용:
- 기존 JSON 로드 경로 유지
- 동적 생성 경로 추가
- 두 경로의 출력을 동일한 포맷으로 통일

```dart
Future<PuzzleData> loadPuzzle(String key, {bool generate = false, ...}) async {
    if (generate) {
        final puzzle = SlitherlinkGenerator().generate(rows, cols, difficulty);
        return PuzzleData(
            answer: PuzzleFormatConverter.toFlutterAnswer(puzzle),
            clue:   PuzzleFormatConverter.toFlutterClue(puzzle),
        );
    } else {
        // 기존 JSON 로드 경로 (변경 없음)
    }
}
```

**의존:** 3단계 완료

---

## 5단계 — 정답 검증 로직 개선

**수정 파일:** `lib/Answer/Answer.dart`

현재 문제:
- `checkCycleSquare`가 사이클 존재 여부만 확인
- 단일 루프 여부, 열린 선 미검증

개선 내용 (2단계 `isValidLoop` 로직 재활용):
```dart
bool isValidSingleLoop(List<List<int>> submit, int rows, int cols) {
    // 1. submit → hEdge/vEdge 변환
    // 2. isValidLoop() 호출 (차수=2 + BFS 연결성)
}
```

> 기존 `checkCycleSquare`는 디버그 전용으로 유지하고, 실제 완성 검사(`checkCompletePuzzle`)에서 새 함수 호출

**의존:** 3단계 완료 (fromFlutterAnswer 활용)

---

## 6단계 — Provider 및 게임 씬 연결

**수정 파일:** `lib/provider/SquareProvider.dart`, `lib/Scene/GameSceneSquare.dart`

### 6-1. SquareProvider 수정
- `init()` 메서드에 동적 생성 퍼즐 초기화 경로 추가
- clue 데이터를 `SquareBox.num` 필드에 반영 (현재 힌트 숫자 미표시 상태 확인 필요)

### 6-2. GameSceneSquare 수정
- 퍼즐 로드 시 `generate: true` 옵션 전달 가능하도록
- 완성 검사 시 5단계의 `isValidSingleLoop` 호출로 교체

**의존:** 4단계, 5단계 완료

---

## 7단계 — UI 개선

**수정 파일:** `lib/widgets/MainUI.dart`

추가 내용:
- 난이도 선택 (EASY / NORMAL / HARD)
- 그리드 크기 선택 (small 10×10 / medium / large)
- 씨드 표시 (공유 기능 기반)

> 6단계까지 완료 후 독립적으로 작업 가능

**의존:** 6단계 완료

---

## 8단계 — 테스트 및 검증

각 단계 완료 후 아래 항목 확인:

| 검증 항목 | 확인 방법 |
|----------|---------|
| 생성된 루프가 단일 폐루프인가 | `isValidLoop()` 통과 여부 |
| 힌트 비율이 난이도와 일치하는가 | 생성된 퍼즐의 공개 셀 수 / 전체 셀 수 |
| 동일 씨드 → 동일 퍼즐인가 | 같은 씨드로 2회 생성 후 비교 |
| 기존 JSON 퍼즐 로드 정상 작동하는가 | 기존 플레이 플로우 회귀 테스트 |
| 동적 생성 퍼즐 정답 검증 정상인가 | 생성 → 정답 입력 → 완성 판정 확인 |

**의존:** 전 단계 완료

---

## 의존 관계 요약

```
1 (데이터 클래스)
└─ 2 (생성 알고리즘)
   └─ 3 (포맷 변환)
      ├─ 4 (로딩 로직)
      │  └─ 6 (Provider·게임 씬)
      │     └─ 7 (UI)
      └─ 5 (검증 개선)
         └─ 6 (Provider·게임 씬)
                └─ 8 (테스트)
```

---

## 병렬 / 직렬 진행 가능 여부

### 직렬 (순서 엄수)

아래 단계는 이전 단계 결과물을 직접 사용하므로 반드시 순서대로 진행해야 합니다.

```
1 → 2 → 3    (핵심 의존 체인, 건너뛸 수 없음)
3 → 4        (포맷 변환 없이 로딩 로직 수정 불가)
3 → 5        (fromFlutterAnswer 없이 검증 개선 불가)
4, 5 → 6     (둘 다 완료 후 Provider 연결)
6 → 8        (연결 완료 후 통합 테스트)
```

### 병렬 가능

3단계 완료 이후, 아래 두 작업은 **서로 독립적**이므로 동시에 진행 가능합니다.

```
3단계 완료
    ├─── [담당자 A] 4단계 (로딩 로직) ──┐
    │                                   ├→ 6단계 (Provider 연결)
    └─── [담당자 B] 5단계 (검증 개선) ──┘
```

7단계(UI 개선)는 6단계가 완료되어 있으면, 8단계(테스트)와 **병렬로** 진행할 수 있습니다.

```
6단계 완료
    ├─── [담당자 A] 7단계 (UI)
    └─── [담당자 B] 8단계 (테스트)
```

### 표로 정리

| 단계 | 진행 방식 | 선행 조건 | 병렬 가능 대상 |
|------|----------|---------|--------------|
| 1단계 | 직렬 | 없음 | — |
| 2단계 | 직렬 | 1단계 | — |
| 3단계 | 직렬 | 2단계 | — |
| 4단계 | **병렬 가능** | 3단계 | 5단계와 동시 진행 가능 |
| 5단계 | **병렬 가능** | 3단계 | 4단계와 동시 진행 가능 |
| 6단계 | 직렬 | 4단계 + 5단계 모두 | — |
| 7단계 | **병렬 가능** | 6단계 | 8단계와 동시 진행 가능 |
| 8단계 | **병렬 가능** | 6단계 | 7단계와 동시 진행 가능 |

---

## 주의사항

- **1~3단계는 기존 코드를 건드리지 않는 신규 파일**이므로 앱 동작에 영향 없음
- **4단계부터 기존 파일 수정** 시작. 기존 JSON 로드 경로는 반드시 유지
- **5단계 검증 개선**은 기존 `checkCompletePuzzle`의 동작을 바꾸므로 회귀 테스트 필수
- **씨드는 Java `java.util.Random`과 Dart `Random`이 다른 시퀀스를 생성**함. 씨드 기반 공유 기능은 Dart 내부에서만 동작하도록 설계
