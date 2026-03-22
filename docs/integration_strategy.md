# 통합 전략 및 최적화 분석

> Java 퍼즐 생성기(`slitherlink-generator-0322`)를 Flutter 앱(`Slither_Project`)에 반영하기 위한 분석

---

## 1. 데이터 포맷 비교

### 1.1 엣지 표현 방식

| 항목 | Java 생성기 | Flutter 앱 |
|------|-----------|----------|
| **엣지 표현** | `boolean[][] hEdge` + `boolean[][] vEdge` (분리) | `List<List<bool>>` 확장 그리드 |
| **그리드 크기** | `(rows+1)×cols` + `rows×(cols+1)` | `(2*rows+1)` 행, 짝수=수평/홀수=수직 |
| **힌트 데이터** | `int[][] clue` (-1~4) | JSON 고정값, 정수 |
| **정답 데이터** | `int[][] solution` (0~4) | 확장 그리드 불린 배열 |
| **데이터 타입** | `int`, `boolean` 원시 배열 | `List<List<int>>`, `List<List<bool>>` |

### 1.2 포맷 변환 로직 (필요)

```
Java hEdge/vEdge → Flutter 확장 그리드

hEdge[r][c] = true  →  answer[r*2][c] = 1    (수평 엣지, 짝수 행)
vEdge[r][c] = true  →  answer[r*2+1][c] = 1  (수직 엣지, 홀수 행)
```

역방향 변환도 동일한 방식으로 가능.

---

## 2. 현재 Flutter 앱에서 누락된 기능

| 기능 | Java 생성기 | Flutter 앱 | 영향도 |
|------|-----------|----------|--------|
| **동적 퍼즐 생성** | `SlitherlinkGenerator.generate()` | 없음 (JSON만) | 극대 |
| **난이도 조절** | EASY/NORMAL/HARD (힌트 비율) | 없음 | 높음 |
| **단일 루프 검증** | `isValidLoop()` (차수 + BFS) | 단순 사이클 탐지만 | 중간 |
| **씨드 재현성** | `Random(seed)` 지원 | 없음 | 중간 |
| **동적 크기** | `rows × cols` 자유 설정 | 10×10 고정 | 높음 |
| **Hex/Tri/Mix** | 완전 구현 | 없음 | 낮음 (추후) |

---

## 3. 정답 검증 비교

| 항목 | Java (`isValidLoop`) | Flutter (`checkCycleSquare`) |
|------|---------------------|------------------------------|
| **검증 시점** | 퍼즐 생성 시 | 디버그 모드 (사후) |
| **알고리즘** | 노드 차수 체크 + BFS 연결성 | DFS 사이클 탐지 |
| **검증 대상** | hEdge/vEdge 불린 배열 | 확장 그리드 불린 배열 |
| **"단일 루프" 검증** | O (모든 노드 차수=2 + 연결 성분 1개) | X (사이클 존재 여부만) |
| **유일해 보장** | O (생성 알고리즘이 보장) | X |

**Flutter 앱의 문제점:** 현재 DFS는 "사이클이 존재하는가"만 확인. 끝이 열린 선(open path)도 통과 가능하고, 여러 사이클이 존재해도 통과 가능.

---

## 4. Dart 포팅 시 주요 변환 포인트

### 4.1 자료구조 변환

| Java | Dart | 주의사항 |
|------|------|---------|
| `HashSet<Long>` | `Set<String>` 또는 `Set<int>` | Long 인코딩 → String 권장 |
| `ArrayList<Integer>` | `List<int>` | 동일 동작 |
| `Queue<Integer>` | `Queue<int>` (dart:collection) | `removeFirst()` 사용 |
| `boolean[][]` | `List<List<bool>>` | 동일 |
| `int[][]` | `List<List<int>>` | 동일 |
| `Collections.shuffle(list, rng)` | `list.shuffle(Random(seed))` | 동일 |

### 4.2 엣지 인코딩

```java
// Java: Long 인코딩 (노드 인덱스 ≤ 9999 제약)
long encode(int a, int b) {
    return (long) Math.min(a,b) * 10000L + Math.max(a,b);
}
```

```dart
// Dart 옵션 1: String 인코딩 (제약 없음, 권장)
String encodeEdge(int a, int b) {
    int lo = min(a, b), hi = max(a, b);
    return '$lo-$hi';
}

// Dart 옵션 2: 비트 시프트 (빠름, 노드 수 ≤ 65535 제약)
int encodeEdge(int a, int b) {
    int lo = min(a, b), hi = max(a, b);
    return (lo << 16) | hi;
}
```

### 4.3 BFS (isValidLoop 이식)

```dart
import 'dart:collection';

bool isValidLoop(List<List<bool>> hEdge, List<List<bool>> vEdge, int rows, int cols) {
    final nodeRows = rows + 1, nodeCols = cols + 1;
    final degree = List.filled(nodeRows * nodeCols, 0);
    int edgeCount = 0;

    // 차수 계산
    for (int r = 0; r <= rows; r++)
        for (int c = 0; c < cols; c++)
            if (hEdge[r][c]) {
                degree[r * nodeCols + c]++;
                degree[r * nodeCols + c + 1]++;
                edgeCount++;
            }
    for (int r = 0; r < rows; r++)
        for (int c = 0; c <= cols; c++)
            if (vEdge[r][c]) {
                degree[r * nodeCols + c]++;
                degree[(r+1) * nodeCols + c]++;
                edgeCount++;
            }

    // 조건 1: 엣지 수 ≥ 4
    if (edgeCount < 4) return false;

    // 조건 2: 모든 활성 노드 차수 = 2
    int startNode = -1;
    for (int i = 0; i < degree.length; i++) {
        if (degree[i] != 0 && degree[i] != 2) return false;
        if (degree[i] == 2 && startNode == -1) startNode = i;
    }

    // 조건 3: BFS 단일 연결 성분
    final visited = <int>{startNode};
    final queue = Queue<int>()..add(startNode);
    while (queue.isNotEmpty) {
        final node = queue.removeFirst();
        for (final neighbor in _adjNodes(node, hEdge, vEdge, rows, cols)) {
            if (!visited.contains(neighbor)) {
                visited.add(neighbor);
                queue.add(neighbor);
            }
        }
    }
    return degree.where((d) => d == 2).length == visited.length;
}
```

### 4.4 난이도 열거형

```dart
enum SlitherlinkDifficulty {
    easy(0.80),
    normal(0.55),
    hard(0.35);

    final double hintRatio;
    const SlitherlinkDifficulty(this.hintRatio);
}
```

---

## 5. 성능 최적화 포인트

### 5.1 경로 추적 최적화 (generateLoop)

**현재 Java 문제점:** `path.indexOf(next)` → O(n) 선형 탐색

```dart
// 최적화: 위치 캐싱으로 O(1)
final positionMap = <int, int>{};  // node → 경로 내 인덱스
int idx = positionMap[next] ?? -1;  // O(1) 조회
```

**성능 향상:** O(n) → O(1)

### 5.2 부분 셔플 최적화 (buildClue)

**현재 Java:** 전체 셀 셔플 후 앞부분만 사용 → O(n log n)

```dart
// Fisher-Yates 부분 셔플 → O(k), k = 공개할 셀 수
List<(int, int)> selectRandomCells(int rows, int cols, int count, Random rng) {
    final cells = [for (int r=0; r<rows; r++) for (int c=0; c<cols; c++) (r,c)];
    for (int i = 0; i < count; i++) {
        int j = i + rng.nextInt(cells.length - i);
        final tmp = cells[i]; cells[i] = cells[j]; cells[j] = tmp;
    }
    return cells.sublist(0, count);
}
```

**성능 향상:** O(n log n) → O(k)

### 5.3 엣지 인코딩 최적화

```dart
// String 대신 비트 시프트 (노드 수 ≤ 65535 조건 충족 시)
int encodeEdge(int a, int b) => (min(a,b) << 16) | max(a,b);
```

**성능 향상:** ~2~3배 (해시 연산 비용 감소)

---

## 6. 통합 전략 비교

### 6.1 옵션 A: Dart 직접 포팅 (권장 — MVP)

**적합 대상:** 빠른 구현, 오프라인 동작 필수

| 항목 | 내용 |
|------|------|
| 개발 기간 | 2~3주 |
| 성능 | 중간 (200~400ms / 퍼즐, 10×10 기준) |
| 오프라인 | 가능 |
| 의존성 | 없음 (순수 Dart) |
| 유지보수 | 쉬움 |

**추가 파일 구조:**
```
lib/
  PuzzleGeneration/
    slitherlink_generator.dart   (generateLoop, isValidLoop, buildClue)
    slitherlink_puzzle.dart      (데이터 클래스)
    difficulty.dart              (열거형)
  Conversion/
    puzzle_format_converter.dart (hEdge/vEdge → Flutter 확장 그리드)
```

### 6.2 옵션 B: 백엔드 API (확장 시)

**적합 대상:** 서버 집중식 관리, 대용량 퍼즐 DB

| 항목 | 내용 |
|------|------|
| 개발 기간 | 3~4주 |
| 성능 | 높음 (서버 고성능) |
| 오프라인 | 불가 (캐시 보완 필요) |
| 유지보수 | 중간 (서버 운영 필요) |

```
POST /api/puzzle/generate
{
  "rows": 10, "cols": 10,
  "difficulty": "NORMAL",
  "seed": 12345
}
```

### 6.3 옵션 C: FFI C++ 네이티브 (고성능 필수 시)

**적합 대상:** 대형 그리드, 실시간 생성 요구

| 항목 | 내용 |
|------|------|
| 개발 기간 | 2~3주 (C++ 전문성 필요) |
| 성능 | 최고 (~30ms / 퍼즐) |
| 오프라인 | 가능 |
| 유지보수 | 어려움 (크로스 플랫폼 빌드) |

### 6.4 종합 비교

| 전략 | 개발 기간 | 성능 | 오프라인 | 유지보수 | 권장 시점 |
|------|---------|------|---------|---------|---------|
| **Dart 포팅** | 2~3주 | 중 | O | 쉬움 | **MVP** |
| **백엔드 API** | 3~4주 | 높음 | X | 중간 | 서비스 확장 시 |
| **FFI C++** | 2~3주 | 최고 | O | 어려움 | 성능 병목 시 |
| **하이브리드** | 4~5주 | 높음 | O | 중간 | 최종 목표 |

---

## 7. 구현 로드맵 (Dart 포팅 기준)

### Phase 1 — 핵심 알고리즘 (Week 1)

- [ ] `SlitherlinkGenerator` Dart 포팅
  - `generateLoop()` (Wilson's LERW)
  - `isValidLoop()` (차수 + BFS)
  - `computeSolution()`
  - `buildClue()`
- [ ] `SlitherlinkDifficulty` 열거형
- [ ] 5×5 그리드 단위 테스트

### Phase 2 — Flutter 통합 (Week 2)

- [ ] `PuzzleFormatConverter` 작성 (hEdge/vEdge → Flutter 확장 그리드)
- [ ] `ReadSquare.dart` 수정 (JSON 로드 + 동적 생성 선택 가능)
- [ ] `SquareProvider` 수정 (동적 생성된 퍼즐 로드 지원)
- [ ] 통합 테스트 (생성 → 로드 → 플레이 → 검증)

### Phase 3 — UX 개선 (Week 3)

- [ ] 난이도 선택 UI (EASY / NORMAL / HARD)
- [ ] 그리드 크기 선택 UI (small / medium / large)
- [ ] 씨드 기반 퍼즐 공유 기능
- [ ] 성능 측정 및 최적화

### Phase 4 — 선택적 확장

- [ ] Hex 격자 지원 (HexGrid 포팅)
- [ ] 백엔드 API 전환 또는 FFI 최적화
- [ ] 온라인 리더보드

---

## 8. 핵심 주의사항

1. **포맷 변환 레이어 필수**: Java의 `hEdge/vEdge` (분리 2차원) ↔ Flutter의 확장 그리드 (통합 2차원) 변환 로직이 없으면 통합 불가

2. **정답 검증 개선 필요**: 현재 Flutter의 `checkCycleSquare`는 단순 사이클 탐지만 수행. Java의 `isValidLoop` 수준(단일 루프 + 모든 노드 차수=2)으로 업그레이드 권장

3. **씨드 관리**: 동일 씨드로 동일 퍼즐을 재현하려면 Dart의 `Random(seed)` 사용 필수. Java의 `java.util.Random`과 동일한 시퀀스를 보장하지 않음 → 씨드별 퍼즐 ID는 독립적으로 관리

4. **Long 인코딩 제약**: Java의 `lo * 10000L + hi` 방식은 노드 인덱스 ≤ 9999(100×100 이하 그리드)에서만 안전. 큰 그리드로 확장 시 Dart에서 비트 시프트 또는 String 방식으로 변경 필요
