# Java 그리드 변형 분석 (Hex / Tri / Mix)

> 분석 대상: `slitherlink-generator-0322/src/main/java/slitherlink/` 의 hex / tri / mix 서브패키지

---

## 1. 그리드 유형별 좌표 체계 및 인접 관계

### 1.1 Square (기준)

| 항목 | 값 |
|------|-----|
| 셀 격자 | `rows × cols` |
| 꼭짓점 격자 | `(rows+1) × (cols+1)` |
| 셀당 엣지 수 | **4** |
| 힌트 범위 | **0~4** |
| 꼭짓점 최대 차수 | **4** |
| 엣지 표현 | `boolean[][] hEdge`, `boolean[][] vEdge` (분리) |

### 1.2 Hex (육각형)

**좌표 체계:**
- 셀: `rows × cols` (flat-top 육각형 배열)
- 꼭짓점: `(2*rows+1) × (cols+1)` → 각 셀 행마다 꼭짓점 행 2개 사용

**셀 (r,c)의 6개 꼭짓점:**
```
TL=(2r,c)    TR=(2r,c+1)       [top]
ML=(2r+1,c)  MR=(2r+1,c+1)    [middle]
BL=(2r+2,c)  BR=(2r+2,c+1)    [bottom]
```

**엣지 순서:** `[top, topRight, botRight, bot, botLeft, topLeft]`

| 항목 | 값 |
|------|-----|
| 셀당 엣지 수 | **6** |
| 힌트 범위 | **0~6** |
| 꼭짓점 최대 차수 | **3** |
| 루프 생성 최대 시도 | **300회** |

### 1.3 Tri (삼각형)

**셀 방향 패턴:**
- `(r+c) % 2 == 0` → ▽ (아래쪽 꼭짓점) — 꼭짓점: `[topL, topR, bot]`
- `(r+c) % 2 == 1` → △ (위쪽 꼭짓점) — 꼭짓점: `[top, botL, botR]`

**꼭짓점 격자:** `(rows+1) × (cols/2+1)` (행별 밀도 단순화)

| 항목 | 값 |
|------|-----|
| 셀당 엣지 수 | **3** |
| 힌트 범위 | **0~3** |
| 꼭짓점 최대 차수 | **6** |
| 루프 생성 최대 시도 | **200회** |
| 특이사항 | `isCellValid(r,c)` 로 격자 경계 처리 필요 |

### 1.4 Mix (Hex + Tri 혼합)

**셀 배치 패턴:**
- `r % 2 == 0` → 육각형 행 (6변)
- `r % 2 == 1` → 삼각형 행 (3변)
- 삼각형 방향: `(r+c) % 2 == 0` → ▽, 홀수 → △

**꼭짓점 매핑 (동적):**
- `Map<Long, Integer> nodeMap` (좌표 → ID)
- 키: `nr * 100_000L + nc`
- 육각형 행의 꼭짓점 열 스케일: `nc = c * 2`

| 항목 | 값 |
|------|-----|
| 셀당 엣지 수 | **6** (육각형) 또는 **3** (삼각형) |
| 힌트 범위 | **0~6** 또는 **0~3** (셀 타입별) |
| 꼭짓점 최대 차수 | **3** (Archimedean tiling 특성) |
| 루프 생성 최대 시도 | **500회** (가장 높음) |

---

## 2. Grid 클래스 공통 인터페이스 및 구현 특성

모든 Grid 클래스는 **명시적 인터페이스 없이** 동일한 메서드 시그니처를 준수합니다.

### 공통 메서드

```java
int[] getCellEdges(int r, int c)       // 셀의 엣지 ID 배열
int[] getEdgeNodes(int eid)            // 엣지의 양쪽 꼭짓점 ID
int getTotalNodes()                    // 총 꼭짓점 수
int getTotalEdges()                    // 총 엣지 수
List<Integer> adjNodes(int node)       // 꼭짓점의 인접 꼭짓점 목록
int findEdge(int a, int b)             // 두 꼭짓점 간 엣지 ID 조회
```

### Grid 클래스별 구현 특성

| 항목 | HexGrid | TriGrid | MixGrid |
|------|---------|---------|---------|
| 꼭짓점 저장 | `int[][] nodeId[nr][nc]` (정적 2D) | `int[][] nodeId[r][c]` (행별 가변) | `Map<Long, Integer> nodeMap` (동적) |
| 엣지 저장 | `List<int[]> edges` + `Map<Long, Integer> edgeMap` | 동일 | `Map<Long, Integer> edgeMap` + `List<int[]> edgeList` |
| 셀-엣지 매핑 | `cellEdges[r][c] = int[6]` | `cellEdges[r][c] = int[3]` | `cellEdges[r][c]` (6개 or 3개) |
| 인접 캐시 | `List<List<Integer>> adjCache` | - | - |
| 특이 메서드 | - | `isCellValid(r,c)` | `isHex(r,c)`, `isPointDown(r,c)`, `cellSides(r,c)` |

---

## 3. Puzzle 클래스 데이터 모델 비교

| 항목 | Square | Hex | Tri | Mix |
|------|--------|-----|-----|-----|
| Grid 참조 | 없음 (암묵적) | `HexGrid grid` | `TriGrid grid` | `MixGrid grid` |
| `clue[][]` | int (-1~4) | int (-1~6) | int (-1~3) | int (타입별) |
| `solution[][]` | int (0~4) | int (0~6) | int (0~3) | int (타입별) |
| 엣지 배열 | `boolean[][] hEdge`, `boolean[][] vEdge` | `boolean[] activeEdge` (1차원) | `boolean[] activeEdge` | `boolean[] activeEdge` |

**Square만 2차원 엣지 배열을 사용**, Hex/Tri/Mix는 1차원 `activeEdge[]` 통일.

---

## 4. Generator 클래스 공통 파이프라인

모든 Generator(Square/Hex/Tri/Mix)가 동일한 3단계를 구현:

```
1. generateLoop()        Wilson's LERW로 루프 생성
2. computeSolution()     각 셀의 활성 엣지 수 계산
3. buildClue()           Difficulty.hintRatio에 따라 힌트 비율 적용
```

### 루프 생성 최소 엣지 요건

| 격자 | minEdges | 최대 시도 | 이유 |
|-----|---------|---------|-----|
| Square | 4 | 100 | 꼭짓점 차수 최대 4 → 루프 길이 충분 |
| Hex | `max(6, rows+cols) * 2` | 300 | 꼭짓점 차수 3 → 경로 제한 |
| Tri | `max(6, rows+cols)` | 200 | 중간 수준 |
| Mix | `max(6, rows+cols) * 2` | 500 | Hex + Tri 혼합 → 가장 복잡 |

---

## 5. 클래스 계층 구조

```
Difficulty (enum) ────────────────────────────────────────
                                                          │
SlitherlinkGenerator    HexSlitherlinkGenerator           │
SlitherlinkPuzzle       HexPuzzle           (독립 구현)   │
PuzzlePrinter           HexPuzzlePrinter                  │
                        HexGrid                           │
                                                          │
                        TriSlitherlinkGenerator           │
                        TriPuzzle                         │
                        TriPuzzlePrinter                  │
                        TriGrid                           │
                                                          │
                        MixSlitherlinkGenerator           │
                        MixPuzzle                         │
                        MixPuzzlePrinter                  │
                        MixGrid ──────────────────────────┘
```

> **명시적 상속 없음** — 각 변형이 완전 독립 구현. 리팩토링 시 추상 기반 클래스 도입 가능.

---

## 6. 테스트 커버리지 (GeneratorTest + 각 Main)

모든 변형에서 공통적으로 검증하는 항목:

| 테스트 항목 | 검증 내용 |
|-----------|---------|
| `testSolutionMatchesEdges` | `solution[r][c]` 값 = 셀 주변 활성 엣지 수 |
| `testLoopDegree` | 모든 활성 꼭짓점 차수 = 2 (20개 랜덤 시드) |
| `testHintRatio` | 공개된 힌트 비율 ≈ `difficulty.hintRatio ± 15%` |
| `testDeterministic` | 동일 시드 → 동일 퍼즐 (재현성) |
| `testMultipleSizes` | 다양한 그리드 크기에서 생성 성공 |

**Mix 추가 테스트:**
- `testCellTypes`: `(r+c) % 2 == 0` → hex, 홀수 → tri 패턴 검증
- `testEdgeCounts`: hex=6엣지, tri=3엣지, 중복 없음

---

## 7. ASCII 렌더링 방식

| 격자 | 셀 높이 | 특수 기호 |
|------|---------|---------|
| Square | 1줄 | `─`, `│` |
| Hex | 4줄 | `─`, `\`, `/` (대각선 혼합) |
| Tri | 2줄 | `\`, `/` (교대 삼각형) |
| Mix | 가변 | H(hex)/T(tri) 레이블 + 복합 엣지 |

---

## 8. Flutter 앱과의 관련성

현재 Flutter 앱은 **Square 격자만 지원**. Hex/Tri/Mix 변형은:
- 독립적인 Grid/Puzzle/Generator 구조로 분리되어 있어 별도 포팅 가능
- 각 변형의 `activeEdge[]` (1차원) 포맷이 Square의 `hEdge/vEdge` (2차원)보다 Flutter 통합에 더 단순할 수 있음
- Mix는 가장 복잡하여 포팅 우선순위 낮음
