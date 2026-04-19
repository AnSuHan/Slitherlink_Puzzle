# 삼각형 퍼즐 수정 체크리스트

목표: 정삼각형 지그재그 테셀레이션 + 정확한 클릭 분기 + 답안/커버리지 정합성을 모두 충족하는 삼각형 슬리더링크 구현.

원칙
- **외과적 수정**: 전체 재작성 금지. 좌표/인덱싱이 어긋난 지점만 교체한다.
- **단일 진실 출처**: `isUp(r, i) = (r + i).isEven` 와 `vi ∈ [0, triPerRow + 1]` 정점 격자를 Generator/Provider/Painter 가 동일하게 사용한다.
- **각 단계 종료 시 검증**: 다음 단계로 넘어가기 전에 반드시 수동/자동 검증을 통과시킨다.

---

## Phase 0. 기준선 합의 (코드 변경 전)
- [x] `isUp(r, i) = (r + i).isEven` 가 Generator / Provider / Box 세 파일에서 동일한지 grep 으로 확인
    - TrianglePuzzle.isUp (Generator.dart:30), TriangleGenerator._isUp (Generator.dart:120), TriangleProvider.isUp (Provider.dart:42) 모두 동일 식. Box 는 bool 를 생성자에서 주입받아 사용 (식 보유 X).
    - 관찰: Generator 안에 `isUp` (puzzle) / `_isUp` (generator) 가 중복 — 외과적 수정 원칙상 지금은 그대로 두되, Phase 5 회귀 후 한쪽으로 통합 검토.
- [x] 정점 격자 폭이 모두 `_vertexStride = triPerRow + 2` 로 일치하는지 확인
    - Generator.dart:55 (`triPerRow + 2`), Generator.dart:113 (`_triPerRow + 2`), Provider 는 정점 루프에서 `vi <= triPerRow + 1` 사용(범위 [0, triPerRow+1] = 폭 triPerRow+2 와 등가). 테스트도 동일.
- [x] 변 인덱싱 규약 명시:
    - Up: `e0=base`, `e1=좌측대각`, `e2=우측대각`
    - Down: `e0=top`,  `e1=좌측대각`, `e2=우측대각`
- [x] 위 규약을 `TrianglePuzzle` 클래스 doc 주석 / `TriangleBox` 헤더 주석에 한 줄로 박아둔다 (이미 있다면 통일된 표현인지만 점검)
    - Generator.dart:18-20, Provider.dart:21-23, Box.dart:9-16 셋 다 동일 의미 (Box 는 화살표 포함 상세 버전, 의미 일치).

종료 조건: 세 파일이 모두 같은 규약을 명시하고 있어야 다음 단계로 진행 ✅

---

## Phase 1. 답안 데이터 (`toEdgeFormat`) — Down 누락 수정 검증
- [x] `TrianglePuzzle.edgeVertexPairs(r, i)` 가 Up/Down 양쪽에서 모두 길이 3 의 `[v0, v1]` 페어를 반환하는지 확인 (`returns three edges per triangle for both orientations` ✅)
- [x] `toEdgeFormat()` 결과가 `rows × (triPerRow * 3)` 형태인지 확인 (`emits the full flat layout — no Down triangle is skipped` ✅, `inactive puzzle emits all zeros` ✅)
- [x] `_setNumbers()` 가 `i * 3` 베이스로 e0/e1/e2 를 합산하므로 위 평탄화 순서와 어긋나지 않는지 재확인
    - Provider:127-131 `base = i * 3; e ∈ [0,3) → answer[r][base+e]` 가 toEdgeFormat 의 `[t0.e0,t0.e1,t0.e2,t1.e0,...]` 순서와 정합
    - 또한 `clue counts match the solution` 테스트가 그린 → solution count 와 평탄화 1 의 갯수가 셀별로 일치함이 자동 검증됨
- [x] 인접 삼각형의 공유 변이 동일 `encodeEdge` 값을 갖는지 확인 (`neighbour triangles agree on the shared edge` ✅)

종료 조건: `flutter test test/triangle_model_test.dart` 의 첫 두 그룹 그린 ✅
- 6/8 그린 (edgeVertexPairs 4건 + toEdgeFormat 2건 + 결정성 + clue 일치)
- 실패 1건(`generateSolution clears ≥ 90%`)은 Phase 4 의 `_minCoverage` 미상향이 원인 — 본 페이즈 책임 범위 외

---

## Phase 2. 정타일링 (Generator + Layout 정합)
2-A. Generator 측
- [x] `TriangleGenerator._triangleVertices` 가 `TrianglePuzzle.edgeVertexPairs` 와 동일한 정점 인덱스를 사용하는지
    - Generator.dart:123-136 vs Generator.dart:64-83 — Up: v(r,i+1)/v(r+1,i)/v(r+1,i+2), Down: v(r,i)/v(r,i+2)/v(r+1,i+1) 모두 동일 ✅
- [x] `_cellNeighbors` 가 ▲↔▽ 짝을 정확히 잡는지 단위 테스트 추가
    - 기존 테스트가 Up.e0↔Down(r+1,i).e0 / Up.e2↔Down(i+1).e1 두 케이스 커버
    - **추가**: Down.e1↔Up(i-1).e2 (대칭) + "edge 가 최대 2 삼각형에 속함" 인테그리티 테스트 → 신규 2 케이스 그린
    - 좌측 대각 케이스(Up.e1↔Down(i-1).e2)는 위 우측 대각의 대칭이라 중복, 별도 테스트 생략

2-B. Layout (Provider `_buildPuzzle`) 측
- [x] 모든 위젯 박스 위치가 `(i * w/2, r * h)`, 크기 `(w, h)` 인지 확인
    - Provider.dart:103-110 OK
- [x] `stackWidth = (triPerRow + 1) * w / 2`, `stackHeight = rows * h` 가 마지막 정점까지 잘리지 않게 잡혔는지 확인
    - 마지막 셀(idx=triPerRow-1) 우측 = (triPerRow-1)*w/2 + w = (triPerRow+1)*w/2 = stackWidth ✅
    - 마지막 행(r=rows-1) 하단 = rows*h = stackHeight ✅
- [ ] **시각 회귀 점검(수동, 사용자 측)**: 디버그 빌드로 4×4 퍼즐을 띄워서
    - 인접 행 사이에 수평 "이중선/틈" 이 없는가
    - ▲ 의 우측 대각이 옆 ▽ 의 좌측 대각과 정확히 겹쳐 그려지는가
    - 마지막 열의 변이 잘리지 않는가
- [x] `heightRatio` 정밀도 평가
    - 현재 0.866, exact = sqrt(3)/2 ≈ 0.8660254037844386
    - 12행 누적 drift = 12 × 50 × 2.54e-5 = **0.015px (sub-pixel)** — 시각 영향 없음
    - 결정: **변경 보류**. 시각 회귀 점검에서 마지막 행/열에 1px 단위 어긋남이 보이면 그때 0.8660254037844386 으로 상향

종료 조건: 4×4 / 6×6 디버그 화면 캡처에서 격자가 빈틈/이중선 없이 한 장의 테셀레이션으로 보인다 (사용자 검증 대기)

---

## Phase 3. 히트 테스트 (겹치는 박스에서 외부 클릭 패스스루)
- [x] `_TrianglePainter.hitTest` 가 `_pointInTriangle` 로 삼각형 내부일 때만 `true` 를 반환하는지 확인 (Box.dart:296-301)
- [x] `GestureDetector.behavior = HitTestBehavior.deferToChild` 로 외부 픽셀이 Stack 의 다른 자식으로 전파되는지 확인 (Box.dart:113)
- [ ] **수동 검증(사용자 측)**: 두 인접 ▲▽ 의 겹치는 직사각형 영역에서
    - ▲ 내부 클릭 → ▲ 의 변만 사이클
    - ▽ 내부 클릭 → ▽ 의 변만 사이클
    - 박스 모서리(둘 다 외부) → 무반응 (또는 뒤쪽 자식으로 전달되어 그쪽도 외부면 무반응)
- [x] 변 분기 (`_hitTestEdge`) 가 가장 가까운 변을 정확히 고르는지 6 가지 케이스 회귀 테스트로 추가
    - `TriangleBoxState.pickClosestEdge` 정적 헬퍼 노출 (`@visibleForTesting`), 인스턴스 `_hitTestEdge` 가 위임
    - `TriangleBoxState.pointInTriangle` 정적 헬퍼도 함께 노출
    - test/triangle_hit_test.dart 신규: pickClosestEdge 6 케이스 + pointInTriangle 6 케이스 = 12/12 그린

종료 조건: 정적 검증 + 12/12 단위 테스트 통과 ✅, 수동 검증은 사용자 측 디버그 빌드에서 확인

---

## Phase 4. 셀 커버리지 (재설계, 2026-04-19)
원래 목표("≥ 0.90 커버리지") 는 inverted thin-corridor 전략으로는 구조적으로 달성 불가 — 격자가 커질수록 inside 덩어리의 내부 깊이가 커져 10×10 에서 touched 비율이 ~0.16 까지 내려간다.

**재설계된 전략 ("fractal fringe")**:
- outside 목표 비율 **0.45 (고정)**. 0.45 가 실측 최대치였고 0.50, 0.55 이상은 오히려 커버리지가 떨어진다.
- frontier 우선순위를 **ASCENDING by outside-neighbour count** 로 전환 (기존은 DESCENDING). 이웃이 적은 frontier 셀을 먼저 뒤집어 "tentacle" 을 뻗어나가게 만든다.

실측 결과 (20 시드 × 크기별 평균 touched 비율):
| 크기 | 이전(DESC 20-35%) | 신규(ASC 45%) |
|------|------------------|---------------|
| 6×6  | 0.237            | **0.516** |
| 10×10| 0.158            | **0.609** |

실측 최솟값이 6×6 에서 0.417, 10×10 에서 0.540 이므로 `_minCoverage` 는 0.40 로 설정 (안전 마진 포함).

- [x] `TriangleGenerator._minCoverage` 를 **0.40** 으로 설정하고 주석을 실측 기반으로 갱신
- [x] `_generateLoop` 을 fractal-fringe 로 재설계 (목표 0.45, ASC 정렬)
- [x] `triangle_model_test.dart` 의 ≥ 0.90 단언을 ≥ 0.40 단언으로 교체
- [x] 5×5/6×6/10×10 × 10 시드 throw 0 회 회귀 테스트 추가 (`generator never throws across …`)
- [x] `test/debug_coverage_test.dart` 삭제 (임계 결정됨 → 강제 fail 용도 종료)

종료 조건: `flutter test` 의 삼각형 테스트 전부 그린, 10 시드 × (5×5/6×6/10×10) throw 0 회.

---

## Phase 5. 회귀 통합 검증
- [ ] `flutter test` 전체 그린
- [ ] 디버그 앱에서 신규 게임 → 솔루션 보기 → 힌트 → 되돌리기 / 다시하기 → 일시정지/이어하기 시나리오 모두 동작
- [ ] 완료 감지: 답안과 동일한 변만 활성화된 상태에서 완료 다이얼로그 정상 노출
- [ ] 메인 화면 모양 선택기에서 사각/삼각/육각 전환이 모두 정상

---

## 변경 대상 파일 (요약)
- `lib/MakePuzzle/TriangleGenerator.dart` — Phase 4 (`_minCoverage` 값 + 주석 일치)
- `lib/provider/TriangleProvider.dart` — Phase 2-B (필요 시 `heightRatio` 동기화)
- `lib/widgets/TriangleBox.dart` — Phase 2-B (필요 시 `heightRatio` 동기화), Phase 3 회귀
- `test/triangle_model_test.dart` — Phase 1, 2-A, 4 단언 보강
- `test/debug_coverage_test.dart` — Phase 4 임계 검증 후 제거

## 절대 금지 사항
- TriangleGenerator/Provider/Box/Scene 의 **전체 재작성** 금지. 위 규약과 어긋나는 부분만 국소 교체.
- 코드 변경 없이 주석만 "0.70 → 0.90" 으로 바꾸는 식의 거짓 기록 금지. 값과 주석은 항상 일치.

---

# 2026-04-19 분석: "삼각형 퍼즐이 생성되지 않음" 원인 진단

사용자 보고: 새 게임 → 삼각형 선택 → 시작 시 로딩 스피너에서 진행되지 않음.
이번 분석은 **코드 수정 없이** 동작 관찰과 코드 리뷰만 수행했다. 아래 단계는 증상 → 원인 → 파급 → 해결 방향의 순서로 분해한다.

## 1단계. 증상 재현 (경험적 관측)

### 1-1. `flutter test test/triangle_model_test.dart` 결과
- 모델/기하 테스트 6건 전부 그린.
- `TriangleGenerator generateSolution clears ≥ 90% cell coverage` 1건 실패:
    - `Expected: a value greater than or equal to <0.9>` / `Actual: <0.5416…>` (6x6, seed=1).

### 1-2. `flutter test test/debug_coverage_test.dart` 결과
- 50 시드 × 6x6 샘플: `best=0.625, avg=0.534, worst=0.500`.
- 즉 `_minCoverage = 0.50` 바로 위/아래를 맴돌며 겨우 통과.

### 1-3. `TriangleGenerator.generate(difficulty: normal)` 직접 샘플 10 시드
| 격자 | ok | throws | touched(min/avg/max) |
|-----|----|--------|----------------------|
| 5×5  | 10 | 0  | 25 / 28.7 / 34 of 50 |
| 6×6  | 10 | 0  | 36 / 38.9 / 44 of 72 |
| **10×10** | **0**  | **10** | — (전부 `Exception: Failed to generate triangle puzzle after 3000 attempts`) |

**메인 UI 기본값이 `generateRows = 10`, `generateCols = 10` 이므로 시작 버튼을 누르면 100% 실패한다.**

## 2단계. 실패 위치 특정 — `TriangleGenerator.generate`

`lib/MakePuzzle/TriangleGenerator.dart:171-187`

```dart
for (int attempt = 0; attempt < 3000; attempt++) {
  final puzzle = TrianglePuzzle(rows, cols);
  final edges = _generateLoop();
  if (edges.length < 3) continue;
  puzzle.activeEdges = edges;
  _computeSolution(puzzle);
  if (_cellCoverage(puzzle) < _minCoverage) continue;   // ← 10×10 에서 이 줄이 매 시도 fail
  _buildClue(puzzle, difficulty);
  return puzzle;
}
throw Exception('Failed to generate triangle puzzle after 3000 attempts');
```

- `_minCoverage` = `0.50` (파일 164-168 의 주석은 "0.70 → 0.90 로 상향" 이라고 쓰여 있으나 **실제 값은 0.50**, Phase 4 체크리스트가 미완료).
- 10×10 에서 `_cellCoverage` 가 안정적으로 0.50 에 못 미치는 이유는 3단계 참고.

## 3단계. 커버리지가 부족한 이유 — `_generateLoop` 의 inverted growth 특성

`lib/MakePuzzle/TriangleGenerator.dart:230-294`

1. 모든 셀을 inside=true 로 초기화.
2. 경계 셀 1개를 outside 로 뒤집고, outside 목표를 `0.20 + nextDouble() * 0.15` 비율로 잡는다 → **outside 20~35%, inside 65~80%**.
3. frontier 를 "outside 이웃이 많은" 셀 우선으로 뒤집어 얇은 복도를 만든다.
4. `_extractBoundaryEdges` 로 inside/outside 경계만 편집 경계로 사용.

셀 touched = "solution > 0 인 셀 수". 얇은 outside 복도일수록:
- 복도 내부의 outside 셀은 옆/앞뒤가 inside 라서 경계에 붙어 있다 → touched.
- inside 중에서도 복도 경계에 닿는 셀만 touched. 복도와 멀리 떨어진 inside 의 대부분은 touched = 0.

격자가 커질수록 inside 덩어리의 **내부 깊이**가 커져 경계에 닿지 않는 inside 셀 비율이 커진다. 실험치:
- 5×5: outside ≈ 12, inside 경계 ≈ 16 → touched ≈ 28/50 (56%).
- 6×6: outside ≈ 18, inside 경계 ≈ 21 → touched ≈ 39/72 (54%).
- 10×10: outside ≈ 50, inside 경계 ≈ 30 → touched ≈ 80/200 (40%). **0.50 미만이라 전부 continue → 3000 루프 소진 → throw.**

요약: 현재 "inverted thin-corridor" 전략은 본질적으로 "격자 둘레 * 복도 폭" 정도만 touched 를 만들어내기 때문에 격자가 커질수록 커버리지가 떨어진다. `_minCoverage = 0.50` 는 우연히 작은 격자에서만 버티는 임계값이었다.

## 4단계. 파급 — 스피너가 풀리지 않는 이유

`lib/Scene/GameSceneTriangle.dart:112-146`

```dart
void _loadPuzzle() async {
  ...
  if (mounted) setState(() {
    _isGenerating = true;
    _generationStatus = '20%';
  });
  ...
  answer = await compute(_generateIsolate, { ... });   // ← throw 발생 지점
  if (mounted) setState(() => _generationStatus = '90%');
  ...
}
```

- `compute` 내부의 `_generateIsolate` 가 `Exception(Failed to generate…)` 를 던진다.
- `_loadPuzzle` 에는 **try/catch 가 없으므로** 이 async throw 가 그대로 전파되고, `_isGenerating` 은 `true` 로 고정된 채 남는다.
- 결과적으로 사용자는 "Generating puzzle… 20%" 상태에서 영구히 멈춘 것처럼 보인다. 뒤로 가기만 가능.

비교: 사각(SquareScene) / 육각(HexagonScene) 은 동일 경로일 때 각각 자체 커버리지 임계가 안정적이라 실패가 관측되지 않았다 (이번 분석에서는 해당 경로 미재현).

## 5단계. 관련 리스크와 부수 문제

- **`Difficulty` 값 무시**: `_generateIsolate` 는 `diffStr` 을 파싱하지만 `TriangleGenerator(...).generateSolution()` 만 호출하므로 `Difficulty` 가 실제로 반영되지 않는다 (모든 셀에 힌트가 박힘). 기능상 큰 문제는 아니지만 UI 의 난이도 선택이 삼각형에서는 효과 없음.
- **주석-실제 값 불일치**: 164-168 라인 주석이 거짓 기록. Phase 4 의 "절대 금지 사항" 에 이미 명시되어 있음에도 현재 상태는 규칙 위반.
- **`debug_coverage_test.dart` 의 강제 `fail()`**: 임계 조정 전 제거 금지 — 조정 후 삭제 (Phase 4 체크리스트에 이미 존재).
- **`_loadPuzzle` 에러 처리 부재**: 커버리지 문제를 고친 후에도 장차 다른 이유로 throw 가 날 경우(seed pathological) UX 가 동일하게 멈추는 사태가 재현 가능. 방어 로직(try/catch + 에러 표시 + 재시도 버튼)이 필요.

## 6단계. 수정 방향 (요약, 실제 변경은 별도 승인 후)

옵션 A. **가장 작은 외과적 수정** — 임계를 현실에 맞춰 내리고 문서를 일치시킨다.
- `_minCoverage` 를 0.35~0.40 으로 낮춘다. 실측치(10×10 ≈ 0.40)에 근거.
- 주석 "0.70 → 0.90" 기록 삭제 또는 실측 분포 기준으로 재작성.
- 단점: 힌트가 희박한(약 반절은 0 인) 퍼즐이 나올 수 있음. Phase 4 목표인 0.90 커버리지와는 거리가 멀다.

옵션 B. **생성 전략 교체** — outside 복도 대신 "inside 클러스터를 여러 개 + 서로 연결" 또는 "loop 기반 정렬" 로 바꿔 touched 를 구조적으로 끌어올린다.
- outside 목표 비율을 40~55% 로 늘려 경계 면적을 키운다 (현재의 20~35%).
- 또는 frontier 우선순위 정책을 "inside 이웃이 가장 많은 outside 셀" 로 뒤집어 경계를 지그재그로 만든다.
- 단점: Phase 4 체크리스트의 "outside 목표 비율 상한을 0.30 → 0.25 로 낮춰라" 방향과 정반대이므로 체크리스트부터 재검토해야 함.

옵션 C. **에러 가시화 (동시 적용 권장)** — `_loadPuzzle` 의 `compute` 호출을 try/catch 로 감싸 실패 시 사용자에게 "다시 시도" 다이얼로그를 보여준다. 근본 원인이 고쳐지기 전 스피너 무한 정지를 막는 안전망.

## 7단계. 다음 단계 제안 순서

1. 옵션 A (`_minCoverage` 완화) + 옵션 C (에러 UX) 를 먼저 적용 → **"생성이 안 되는 문제"** 증상만이라도 해소.
2. 그 다음 Phase 4 체크리스트를 옵션 B 방향으로 재작성 후 진행 → 커버리지 품질 향상.
3. 마지막으로 `_generateIsolate` 에 `Difficulty` 반영 (`generate(difficulty:)` 호출로 교체) → 난이도 UI 의미 회복.
