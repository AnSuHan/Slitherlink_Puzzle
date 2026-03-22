# 아키텍처 문서

## 개요

이 앱은 Flutter의 **Provider 패턴**을 기반으로 한 단방향 상태 흐름 아키텍처를 사용합니다.

---

## 전체 화면 흐름

```
main.dart
  └─> Splash (Firebase 초기화, UserInfo 로딩)
        └─> EnterScene (메인 메뉴)
              ├─> MainUI (메뉴 UI, 설정, 인증 다이얼로그)
              ├─> HowToPlay (튜토리얼)
              └─> GameSceneSquare (게임 플레이)
                    └─> SquareProvider (상태 관리)
                          ├─> GameUI (앱바, 북마크, 메뉴)
                          └─> SquareBox (퍼즐 셀 위젯)
```

---

## 레이어 구조

```
┌─────────────────────────────────────┐
│           UI Layer (Widgets)        │
│  SquareBox  GameUI  MainUI          │
├─────────────────────────────────────┤
│         Screen Layer                │
│  GameSceneSquare  EnterScene        │
├─────────────────────────────────────┤
│       State Management Layer        │
│         SquareProvider              │
├─────────────────────────────────────┤
│          Data Layer                 │
│  ReadSquare  Answer  UserInfo       │
├─────────────────────────────────────┤
│        Platform Layer               │
│  ExtractData  ExtractDataWeb        │
├─────────────────────────────────────┤
│       External Services             │
│  Firebase Auth  Cloud Firestore     │
└─────────────────────────────────────┘
```

---

## 핵심 컴포넌트

### SquareProvider (lib/provider/SquareProvider.dart)
앱의 핵심 상태 관리자. `ChangeNotifier`를 상속하며 모든 게임 로직을 담당합니다.

**주요 상태:**
```dart
List<List<SquareBox>> puzzle     // 화면에 표시되는 퍼즐 상태
List<List<int>> submit           // 사용자가 입력한 선 상태
List<List<int>> answer           // 정답 데이터
List<List<List<int>>> doSubmit   // undo/redo 히스토리 스택
int doPointer                    // 현재 undo/redo 위치
int _isUpdating                  // 동기화 상태 플래그 (0~3)
```

**주요 메서드:**

| 메서드 | 역할 |
|--------|------|
| `updateSquareBox()` | 선 배치 & 색상 전파 |
| `showHint()` | 힌트 표시 |
| `checkCompletePuzzle()` | 완성 여부 확인 |
| `setDo()` | 현재 상태를 undo 스택에 저장 |
| `undoDo()` / `redoDo()` | 실행 취소 / 다시 실행 |
| `saveLabel()` / `loadLabel()` | 북마크 저장/불러오기 |
| `quitDoValue()` | 종료 시 상태 저장 |

---

### SquareBox (lib/widgets/SquareBox.dart)
퍼즐의 단일 셀을 표현하는 위젯이자 데이터 모델입니다.

**선 상태 값:**

| 값 | 의미 |
|----|------|
| `0` | 빈 상태 (선 없음) |
| `1~15` | 사용자가 그린 선 (색상 번호) |
| `-4` | X 표시 (선 없음 확정) |
| `-1` | 비활성화 |
| `-2` | 오답 표시 |
| `-3` | 힌트 (올바른 선) |
| `-5` | 힌트 (잘못된 선) |

---

### ReadSquare (lib/MakePuzzle/ReadSquare.dart)
`puzzle[row][col]` (셀 기반) ↔ `submit[row][col]` (선 기반, 2배+1 크기) 간 변환을 담당합니다.

**좌표 변환 구조:**

```
puzzle 3x3 → submit 7x(홀짝 교대)

Row 0: [─ ─ ─]          ← 상단 수평선
Row 1: [│ □ │ □ │]      ← 수직선 + 셀
Row 2: [─ ─ ─]          ← 수평선
Row 3: [│ □ │ □ │]
Row 4: [─ ─ ─]
Row 5: [│ □ │ □ │]
Row 6: [─ ─ ─]          ← 하단 수평선
```

---

### Answer (lib/Answer/Answer.dart)
`Answer/Square_small.json`에서 1410개의 퍼즐 정답을 로드합니다.

- JSON 형식: 각 퍼즐은 10x20 boolean 배열
- `checkCycleSquare()` / `dfs()`: DFS로 단일 루프 유효성 검증 (디버그용)
- `checkDuplicate()`: 중복 퍼즐 감지

---

### UserInfo (lib/User/UserInfo.dart)
사용자 설정 및 진행 상황을 관리합니다.

```dart
Map<String, String> setting = {
  "theme": "default|warm|cool|earth|pastel|vibrant",
  "language": "english|korean",
  "appbar_mode": "fixed|toggle",
  "button_alignment": "left|right"
};

Map<String, int> progress = {
  "square_small": 0,    // 완료한 퍼즐 수
};

Set<String> continuePuzzle = {};  // 진행 중인 퍼즐 키 목록
```

---

### Platform Layer (lib/Platform/)
플랫폼별 로컬 저장소 추상화:

| 파일 | 사용 플랫폼 | 저장소 |
|------|------------|--------|
| `ExtractData.dart` | Android, iOS, Windows, macOS, Linux | SharedPreferences |
| `ExtractDataWeb.dart` | Web | localStorage (js interop) |

---

### ThemeColor (lib/ThemeColor.dart)
- `lineColorList`: 15가지 선 색상 정의
- `themeColorList`: 8가지 UI 테마 색상 세트 (배경, 텍스트, 버튼 등)

---

## 데이터 흐름

### 선 배치 흐름

```
사용자 탭 (SquareBox)
  → SquareProvider.updateSquareBox()
    1. _isUpdating == 0 대기
    2. removeHintLine() 실행
    3. _isUpdating = 1 설정
    4. 선 상태 업데이트 (up/down/left/right)
    5. getNearColor() → 인접 색상 감지
    6. 색상 충돌 시 getOldColorList() → 재귀적 색상 전파
    7. setDo() 호출 (undo 스택에 저장)
    8. _isUpdating = 0 설정
  → notifyListeners()
  → UI 리빌드
```

### 저장/불러오기 흐름

```
북마크 저장 (GameUI.saveData)
  → SharedPreferences에 submit 직렬화 저장
  → undo 스택도 함께 저장

북마크 불러오기 (GameUI.loadData)
  → SharedPreferences에서 submit 역직렬화
  → puzzle 재구성
  → undo 스택 복원
```

---

## 동기화 메커니즘 (_isUpdating)

비동기 연산 간 레이스 컨디션 방지를 위한 상태 플래그:

```
0 → 유휴 상태 (모든 함수 진입 가능)
1 → updateSquareBox 실행 중 (setDo 진입 가능)
2 → setDo 실행 중
3 → setDo 완료 (updateSquareBox 종료 대기)

실행 순서: updateSquareBox( removeHintLine() → setDo() )
```

각 함수별 대기 조건:
- `updateSquareBox()`: 0이 될 때까지 대기
- `removeHintLine()`: 0이 될 때까지 대기
- `setDo()`: 1이 될 때까지 대기 → 2 설정 → 완료 시 3 설정
- `refreshSubmit()`: 0 또는 2가 될 때까지 대기
- `checkCompletePuzzleCompletely()`: 0이 될 때까지 대기
