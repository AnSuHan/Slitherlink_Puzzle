# 최적화 분석 개요

> Java 퍼즐 생성기(`slitherlink-generator-0322`)를 Flutter 앱에 반영하기 위한 분석 결과 요약
> 분석일: 2026-03-22

---

## 분석 문서 목록

| 문서 | 내용 |
|------|------|
| [java_core_algorithm.md](java_core_algorithm.md) | Java Square 격자 핵심 알고리즘 (Wilson's LERW, 검증, 힌트 생성) |
| [java_grid_variants.md](java_grid_variants.md) | Java Hex / Tri / Mix 그리드 변형 분석 |
| [flutter_app_analysis.md](flutter_app_analysis.md) | 현재 Flutter 앱 퍼즐 로직 전체 분석 |
| [integration_strategy.md](integration_strategy.md) | 통합 전략, 포맷 변환, 구현 로드맵 |

---

## 핵심 발견사항 요약

### Java 생성기가 제공하는 것

| 기능 | 설명 |
|------|------|
| **동적 퍼즐 생성** | Wilson's LERW → 단일 폐루프 생성 → 힌트 배치 |
| **난이도 조절** | EASY 80% / NORMAL 55% / HARD 35% 힌트 공개 비율 |
| **유효성 검증** | 노드 차수=2 + BFS 연결성 → 완전한 단일 루프 보장 |
| **씨드 재현성** | 동일 씨드 → 동일 퍼즐 |
| **다양한 그리드** | Square / Hex / Tri / Mix 4종 |
| **동적 크기** | `rows × cols` 자유 설정 |

### Flutter 앱의 현재 한계

| 한계 | 상세 |
|------|------|
| 퍼즐 생성 불가 | JSON 파일에 하드코딩된 퍼즐만 사용 |
| 고정 크기 | 10×10 (small)만 지원 |
| 단일 타입 | Square 격자만 지원 |
| 불완전한 검증 | 단순 사이클 탐지만 수행 (단일 루프 미검증) |
| 난이도 없음 | 모든 퍼즐이 JSON에 고정된 힌트 수 |

---

## 포맷 변환 핵심 (필수 구현)

Java와 Flutter는 엣지 표현 방식이 다릅니다:

```
Java 생성기:                       Flutter 앱:
hEdge[r][c] (수평, (rows+1)×cols)  answer[r*2][c]    (짝수 행 = 수평 엣지)
vEdge[r][c] (수직, rows×(cols+1))  answer[r*2+1][c]  (홀수 행 = 수직 엣지)
```

이 변환 로직 없이는 두 시스템 통합 불가.

---

## 권장 통합 전략

**Phase 1 (MVP, 2~3주): Dart 직접 포팅**
1. `SlitherlinkGenerator` → `slitherlink_generator.dart` 포팅
2. `PuzzleFormatConverter` 작성 (hEdge/vEdge ↔ Flutter 확장 그리드)
3. `ReadSquare.dart` + `SquareProvider` 수정 (동적 생성 지원)
4. 난이도 선택 UI 추가

**Phase 2 (선택, 이후): 성능/기능 확장**
- 그리드 크기 선택 UI
- Hex 격자 포팅
- 씨드 기반 퍼즐 공유
- 필요시 백엔드 API 또는 FFI로 전환

---

## 정답 검증 개선 필요

| 항목 | 현재 Flutter | 목표 (Java 수준) |
|------|------------|----------------|
| 알고리즘 | DFS 사이클 탐지 | 노드 차수=2 + BFS 연결성 |
| 단일 루프 보장 | X | O |
| 다중 루프 감지 | X | O |
| 열린 선 감지 | X | O |
