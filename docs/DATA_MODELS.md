# 데이터 모델 및 저장 구조

## 1. 핵심 데이터 모델

### SquareBox

퍼즐의 단일 셀을 표현하는 모델 + 위젯.

```dart
class SquareBox {
  int row;           // 퍼즐 내 행 위치
  int column;        // 퍼즐 내 열 위치
  int up;            // 위쪽 선 상태
  int down;          // 아래쪽 선 상태
  int left;          // 왼쪽 선 상태
  int right;         // 오른쪽 선 상태
  int num;           // 셀 제약 숫자 (0~4, -1=숫자 없음)
  int boxColor;      // 셀 배경색 (0=일반, 1=하이라이트)
  bool isFirstRow;
  bool isFirstColumn;
  bool isHowToPlay;  // 튜토리얼용 여부
}
```

### 선 상태 값 정의

```
 0  : 빈 상태 (선 없음)
1~15: 사용자가 그린 선 (색상 번호)
 -1 : 비활성화 (표시 불가)
 -2 : 오답 표시
 -3 : 힌트 - 올바른 선 (깜빡임)
 -4 : X 표시 (선 없음 확정)
 -5 : 힌트 - 잘못된 선 (깜빡임)
```

---

## 2. 퍼즐 상태 배열

### puzzle (셀 기반)

```dart
List<List<SquareBox>> puzzle
// 크기: [rows][cols]
// 각 SquareBox가 4방향 선 상태를 가짐
```

### submit (선 기반)

```dart
List<List<int>> submit
// 크기: [(rows*2)+1][가변]
// 홀수 행: 수직선 (길이 = cols+1)
// 짝수 행: 수평선 (길이 = cols)
```

### answer (정답 데이터)

```dart
List<List<int>> answer
// submit과 동일한 구조
// 1=선 있음, 0=선 없음
```

---

## 3. SharedPreferences 저장 키 구조

모든 키는 `shape_size_progress` 형식을 기본으로 합니다.
예: `square_small_0` (첫 번째 small 크기 사각형 퍼즐)

### 퍼즐 진행 키

| 키 | 예시 | 생성 위치 | 삭제 위치 | 설명 |
|----|------|-----------|-----------|------|
| `shape_size_progress` | `square_small_0` | `MainUI.getStartButton()` | `SquareProvider.showComplete()` | 현재 플레이 중인 퍼즐 식별자 |

### 북마크 키 (Red/Green/Blue)

| 키 | 예시 | 생성 위치 | 삭제 위치 | 설명 |
|----|------|-----------|-----------|------|
| `shape_size_progress_color` | `square_small_0_Red` | `GameUI.saveData()` | `GameUI.clearLabel()` / `showComplete()` | 북마크 submit 데이터 |
| `shape_size_progress_color_do` | `square_small_0_Red_do` | `SquareProvider.controlDo()` | `GameUI.clearLabel()` / `showComplete()` | undo/redo 메타데이터 |
| `shape_size_progress_color_doValue` | `square_small_0_Red_doValue` | `SquareProvider.quitDoValue()` | `showComplete()` | doPointer, doIndex 값 |
| `shape_size_progress_color_doSubmit` | `square_small_0_Red_doSubmit` | `SquareProvider.quitDoValue()` | `showComplete()` | 전체 undo 스택 직렬화 |

### 현재 게임 상태 키 (뒤로가기 후 재개용)

| 키 | 예시 | 설명 |
|----|------|------|
| `shape_size_progress__doValue` | `square_small_0__doValue` | 현재 doPointer, doIndex |
| `shape_size_progress__doSubmit` | `square_small_0__doSubmit` | 전체 undo 스택 |

> 참고: `_color` 부분이 빈 문자열 `_`로 표시됨 (현재 게임 = 색상 없음)

### 설정 키

| 키 | 타입 | 설명 |
|----|------|------|
| `setting` | String (JSON) | 앱 전체 설정 |

설정 값 구조:
```json
{
  "theme": "default",
  "language": "korean",
  "appbar_mode": "fixed",
  "button_alignment": "right"
}
```

---

## 4. 사용자 진행 상황 데이터

### UserInfo

```dart
// 진행 상황 (로컬 + Firebase 동기화)
Map<String, int> progress = {
  "square_small": 0,      // 완료한 퍼즐 수
  "triangle_small": 0     // (예정 기능)
};

// 진행 중인 퍼즐 목록
Set<String> continuePuzzle = {};
// 예: {"square_small_3", "square_small_7"}

// 앱 설정
Map<String, String> setting = {
  "theme": "default|warm|cool|earth|pastel|vibrant",
  "language": "english|korean",
  "appbar_mode": "fixed|toggle",
  "button_alignment": "left|right"
};
```

### Firebase Firestore 구조

```
users/
  {uid}/
    progress:
      square_small: 42
    continuePuzzle: ["square_small_3", "square_small_7"]
```

---

## 5. 정답 JSON 형식

`Answer/Square_small.json`:

```json
[
  // 퍼즐 #0
  [
    [false, true, false, true, ...],   // 행 0 (수평선, 길이=cols)
    [true, false, true, false, ...],   // 행 1 (수직선, 길이=cols+1)
    [false, false, true, true, ...],   // 행 2 (수평선)
    ...
  ],
  // 퍼즐 #1
  [...],
  ...
]
```

- 총 1410개 퍼즐
- 각 퍼즐: 10행 × (가변) 열 boolean 배열
- submit 배열과 동일한 구조 (true=1, false=0으로 변환)

---

## 6. Undo/Redo 스택 직렬화

`doSubmit`은 저장 시 문자열로 직렬화됩니다:

```
형식: "행길이,값,값,...|행길이,값,값,...;행길이,...|..."
      └─ 한 submit ─┘  └─── 한 submit ───┘
      (행들은 |로 구분, submit은 ;로 구분)
```

불러올 때 역직렬화하여 `List<List<List<int>>>` 복원.

---

## 7. 테마 색상 구조

`ThemeColor.dart`:

```dart
// 선 색상 15가지 (인덱스 1~15)
List<Color> lineColorList = [
  Colors.transparent,  // 0 (미사용)
  Colors.blue,         // 1
  Colors.red,          // 2
  ...                  // 3~15
];

// UI 테마 (7가지 + custom)
List<Map<String, Color>> themeColorList = [
  {
    "background": Color(...),
    "text": Color(...),
    "button": Color(...),
    "line": Color(...),
    ...
  },
  // warm, cool, earth, pastel, vibrant, ...
];
```
