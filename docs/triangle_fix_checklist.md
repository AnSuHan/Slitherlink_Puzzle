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

## Phase 4. 셀 커버리지 (목표 ≥ 90%)
현재 상태: `_minCoverage = 0.50` 이지만 주석은 "Bumped from 0.70 → 0.90" 라고 거짓 기록. 실수정 필요.

- [ ] `TriangleGenerator._minCoverage` 를 `0.90` 으로 상향
- [ ] `_generateLoop` 의 outside 목표 비율 (`0.20 + 0.15`) 이 이 임계를 안정적으로 통과하는지 분포 측정
    - `test/debug_coverage_test.dart` 를 일회성으로 돌려 best/avg/worst 출력
    - avg 가 0.95 이상, worst 가 0.90 이상이면 OK
- [ ] 통과율이 낮으면:
    - outside 목표 비율 상한을 `0.30` → `0.25` 로 낮춰 inside 비중을 키운다
    - 또는 frontier 우선순위를 "outside 이웃이 가장 많은 셀" 로 더 강하게 (현재의 reverse 정렬 강화)
- [ ] `generate(...)` 시도 횟수 3000 이내에 throw 가 발생하지 않는지 5×5 / 6×6 / 7×7 모두에서 확인
- [ ] `generateSolution ≥ 0.90` 단언 테스트 (`generateSolution clears ≥ 90% cell coverage`) 그린
- [ ] 임계 조정이 끝나면 `debug_coverage_test.dart` 의 강제 fail 을 제거하거나 파일 자체 삭제

종료 조건: 위 단위 테스트 + 임의 시드 30 회 시뮬레이션에서 throw 0 회

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
