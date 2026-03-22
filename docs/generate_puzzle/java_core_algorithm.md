# Java 핵심 알고리즘 분석

> 분석 대상: `slitherlink-generator-0322/src/main/java/slitherlink/`의 핵심 클래스

## 1. SlitherlinkPuzzle 데이터 구조

### 그리드 크기 체계

| 개념 | 크기 | 설명 |
|------|------|------|
| 셀(Cell) | `rows × cols` | 퍼즐의 기본 단위, 힌트 숫자가 표시됨 |
| 꼭짓점(Node) | `(rows+1) × (cols+1)` | 엣지의 끝점 |
| 수평 엣지(hEdge) | `(rows+1) × cols` | 노드(r,c) ↔ 노드(r, c+1) |
| 수직 엣지(vEdge) | `rows × (cols+1)` | 노드(r,c) ↔ 노드(r+1, c) |

### 주요 멤버 변수

```java
int rows, cols;           // 셀 격자 크기
int[][] clue;             // 표시할 힌트 (-1: 비공개, 0~4: 엣지 수)
int[][] solution;         // 완전한 정답 (검증/디버그용)
boolean[][] hEdge;        // 수평 엣지 상태 (true = 루프에 포함)
boolean[][] vEdge;        // 수직 엣지 상태 (true = 루프에 포함)
```

### 셀 주변 엣지 계산

```java
int countEdgesAround(int r, int c) {
    return hEdge[r][c]   + hEdge[r+1][c]    // 위/아래
         + vEdge[r][c]   + vEdge[r][c+1];   // 왼쪽/오른쪽
}
// 범위: 0~4
```

---

## 2. 퍼즐 생성 알고리즘 (SlitherlinkGenerator)

5단계 파이프라인으로 구성:

```
generateLoop()     루프 생성 (Wilson's LERW, 최대 100회 재시도)
     ↓
decodeEdges()      엣지 집합 → hEdge/vEdge 배열 변환
     ↓
isValidLoop()      단일 폐루프 검증 (차수 + BFS 연결성)
     ↓
computeSolution()  각 셀 주변 활성 엣지 수 계산
     ↓
buildClue()        난이도에 따라 일부 셀 힌트 숨김
```

### 단계 1: generateLoop — Wilson's Loop-Erased Random Walk

```
1. 랜덤 시작 노드 선택
2. 무작위 보행 (상/하/좌/우 이웃 노드로 이동)
3. 시작 노드로 돌아오고 경로 길이 ≥ 4 → 루프 완성
4. 이미 방문한 노드 재방문 → Loop Erasure (해당 노드 이후 경로 삭제)
5. 최대 totalNodes × 10 스텝 시도
```

**엣지 인코딩 (Long):**
```java
long encodeEdge(int a, int b) {
    int lo = Math.min(a, b);
    int hi = Math.max(a, b);
    return lo * 10000L + hi;  // 노드 인덱스 ≤ 9999 조건
}
```
→ `Set<Long>`으로 중복 없는 엣지 집합 관리

### 단계 2: decodeEdges

```java
int a = (int)(code / 10000L);          // 첫 번째 노드 인덱스
int b = (int)(code % 10000L);          // 두 번째 노드 인덱스
int ra = a / nodeCols, ca = a % nodeCols;
int rb = b / nodeCols, cb = b % nodeCols;

if (ra == rb) hEdge[ra][Math.min(ca, cb)] = true;   // 수평 엣지
else          vEdge[Math.min(ra,rb)][ca]  = true;   // 수직 엣지
```

### 단계 3: isValidLoop 검증

**조건 1 — 모든 활성 노드의 차수 = 2:**
```java
int[] degree = new int[nodeRows * nodeCols];
// hEdge, vEdge를 순회하며 양 끝 노드의 degree 증가
for (int d : degree) {
    if (d != 0 && d != 2) return false;
}
```

**조건 2 — 엣지 수 ≥ 4**

**조건 3 — BFS 단일 연결 성분:**
```java
// 차수=2 노드 중 하나에서 시작, BFS로 도달 가능한 모든 노드 탐색
// 모든 차수=2 노드가 동일한 연결 성분이어야 함
```

루프가 유효하지 않으면 최대 100회 재시도.

### 단계 4: computeSolution

```java
solution[r][c] = hEdge[r][c] + hEdge[r+1][c]
               + vEdge[r][c] + vEdge[r][c+1];
// 범위: 0~4
```

### 단계 5: buildClue (난이도별 힌트)

```java
int toReveal = (int) Math.round(total * difficulty.hintRatio);
List<int[]> cells = shuffledCellList();  // 전체 셀을 무작위 순서로
for (int i = 0; i < toReveal; i++) {
    clue[cells[i][0]][cells[i][1]] = solution[cells[i][0]][cells[i][1]];
}
// 나머지 셀은 -1 (비공개)
```

---

## 3. Difficulty 열거형

```java
public enum Difficulty {
    EASY(0.80),    // 셀의 80% 힌트 공개
    NORMAL(0.55),  // 셀의 55% 힌트 공개
    HARD(0.35);    // 셀의 35% 힌트 공개

    public final double hintRatio;
}
```

---

## 4. PuzzlePrinter 출력 형식

```
[Solution]
·─·─· · ·
│ 3 1 2 │
· ·─·─·─·
│ 2   1 │
·─· ·─· ·

[Puzzle (Clue)]
· · · · ·
    1 3 2
· ·─·─· ·
    2   1
· · · · ·
```

| 기호 | 의미 |
|------|------|
| `·` | 꼭짓점(Node) |
| `─` | 활성 수평 엣지 |
| `│` | 활성 수직 엣지 |
| 공백 | 비활성 엣지 또는 숨겨진 힌트 |
| 숫자 | 셀 힌트 값 |

**통계 출력 (printStats):** 그리드 크기 / 공개 힌트 수 및 비율 / 총 엣지 수

---

## 5. 핵심 자료구조 요약

| 자료구조 | 용도 | 위치 |
|---------|------|------|
| `Set<Long>` | 루프 엣지 저장 (중복 제거) | `generateLoop()` |
| `List<Integer>` + `Set<Integer>` | 경로 추적 (순서 유지 + O(1) 탐색) | `generateLoop()` |
| `int[] degree` | 노드 차수 계산 | `isValidLoop()` |
| `Queue<Integer>` | BFS 탐색 | `isValidLoop()` |
| `boolean[][]` | hEdge, vEdge 저장 | 전체 |
| `int[][]` | solution, clue 저장 | 전체 |

> **Union-Find 미사용** — 연결성 검증은 BFS로 수행

---

## 6. 복잡도 분석

| 작업 | 시간 복잡도 |
|------|-----------|
| `generateLoop()` | O(totalNodes × maxSteps) |
| `isValidLoop()` | O(V + E) (BFS) |
| `computeSolution()` | O(rows × cols) |
| `buildClue()` | O(n log n) (셔플) |
| **전체 `generate()`** | O(100 × (totalNodes × 10 + BFS)) |

---

## 7. 설계 특징

1. **Wilson's LERW**: NP-hard인 Hamiltonian 루프 대신 근사 알고리즘 사용 → 빠르고 실용적
2. **재시도 방식**: 루프 검증 실패 시 최대 100회 재시도 (실패율 극히 낮음)
3. **정답-힌트 분리**: `solution`과 `clue` 배열을 분리 → 검증/디버그 용이
4. **씨드 지원**: `Random(seed)` 사용으로 동일 씨드 시 동일 퍼즐 재현 가능
