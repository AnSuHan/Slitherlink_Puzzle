# 제약 전파 (Constraint Propagation) 로직 — 상세

본 문서는 Slitherlink 의 4종 도형(Square / Hexagon / Triangle / Trihex) 풀이 보조 시스템이 **자동으로 비활성(-1) 처리해야 하는 변** 과 그 추론 과정을 정의한다. Provider 코드 (`*Provider.dart` 의 `_applyConstraints` / `_runLookAhead`, Square 는 `square_propagation_core.dart` 의 top-level 함수) 는 본 문서의 규칙을 그대로 반영해야 한다.

처음 읽는 사람도 이해할 수 있도록, 각 규칙마다 **왜 그런지** 와 **어떻게 적용하는지** 를 그림과 함께 풀어 설명한다.

> ## 🚨 절대 규칙 — 자동 비활성 타이밍 (절대 어기지 말 것)
> 이 프로젝트에서 **가장 자주 회귀되는 버그**다. 어기면 즉시 되돌려야 한다.
>
> 1. **첫 화면(init)은 단서만 보인다.** init 에서는 **자명한 직접 규칙
>    (`_propagateDirect` — 0-clue 셀/starved 꼭짓점 등)만** 적용한다. **init 에
>    look-ahead(가설 전파, `_applyConstraints`)를 절대 돌리지 마라** — 풀 수 없는
>    변이 대량 -1 이 되며 남은 후보(=정답 라인)가 첫 화면에 드러나는 스포일러가 된다.
> 2. **사용자가 첫 수를 둔 뒤에야** `updateEdge`/`updateSquareBox` →
>    `_applyConstraints` 에서 **직접 추론 + look-ahead(§3)** 가 함께 돌아, 그 수에서
>    논리적으로 따라오는 자동 비활성이 나타난다. **look-ahead 는 라이브 플레이에서
>    반드시 살아 있어야 한다** — 라이브에서 look-ahead 를 빼면 "선을 충분히 그었는데
>    나머지 X 가 안 뜬다"는 회귀가 난다(2026-07-08 이 실수가 실제로 있었음).
> 3. 4개 도형 모두 위 두 규칙을 지킨다. init 에 `_applyConstraints` 를 넣지 말고,
>    `updateEdge` 경로에서 look-ahead 를 제거하지 마라.
>
> 근거·이력: 프로젝트 메모리 `project_init_no_lookahead`. 솔버(`canAutoSolve`/
> `isLogicSolvable`/on-screen 솔버)는 정답을 참조하지 않고 같은 추론+백트래킹으로
> 완주한다(`project_solver_answerfree_architecture`).

---

## 0. 용어 정리

먼저 본 문서에서 쓰는 단어부터 통일한다.

| 단어 | 코드 값 | 의미 |
|---|---|---|
| **변(edge)** | — | 셀과 셀 사이의 한 선분. Slitherlink 에서 "그어진다 / 안 그어진다" 의 단위. |
| **active (drawn)** | `≥ 1` | 사용자가 그어 둔 변. 색은 chain id 로 분기. |
| **undecided** | `0` | 아직 결정되지 않은 변 (회색/투명 상태). |
| **disabled** | `-1` | "이 변은 절대 그어질 수 없다" 라고 시스템이 추론한 변. UI 에서는 더 어두운 색으로 표시. |
| **user-questioned** | `-2` | 사용자가 자동 비활성(-1) 변을 탭해 "이 -1 에 동의 안 함" 으로 마킹한 변 (빨강). 시각적 마킹일 뿐, 그어지지는 않는다. |
| **user-X** | `-4` | 사용자가 그어 둔 변을 탭해 X 로 명시적 비활성화한 변. 그어지지 않는다는 점은 -1 과 동일하지만, 사용자 의지로 잠긴 변. |
| **force-draw** | (시뮬 내부 1) | "이 변은 반드시 그어져야 한다" 라고 가설 시뮬레이션이 도출한 변. **실제 puzzle 에는 절대 영구 기록되지 않는다.** |
| **clue (num)** | 셀의 정수 | 셀 둘레에 그어져야 하는 정확한 변 개수. |
| **hidden clue** | `num < 0` | 난이도 마스킹으로 가려진 클루. 어떤 propagator 도 이런 셀을 건드리면 안 된다 — 빠뜨리면 한 번의 입력에 보드 전체가 비활성화되는 사고가 난다. |

도형별 셀 둘레 변 수 / 클루 범위:

| 도형 | 셀 둘레 변 | num 범위 |
|---|---|---|
| Square | 4 | 0..4 |
| Hexagon | 6 | 0..6 |
| Triangle | 3 | 0..3 |
| Trihex | hex 셀 6 / tri 셀 3 | 동일 |

---

## 1. 슬리더링크 기본 규칙 (모든 추론의 근거)

자동 추론은 결국 아래 두 가지 보편 규칙의 결과물이다. 추론 규칙을 만들 때마다 "이게 왜 옳은가?" 를 이 규칙으로 환원할 수 있어야 한다.

### 1-1. 셀 규칙
> 클루 셀의 둘레 변 중 정확히 `num` 개가 그어진다.

예시 (Square num=2 셀):

```
  ┌─?─┐    ?: 미정 변. 정확히 2개가 그어져야 한다.
  ?   ?
  └─?─┘
```

가능한 조합은 `C(4, 2) = 6` 가지. 추가 정보(예: 인접 셀 / 꼭짓점 제약) 없이는 어느 변이 그어질지 결정 불가.

### 1-2. 꼭짓점 규칙 (degree 0 또는 2)
> 모든 꼭짓점에서 그어진 변의 개수는 **0 또는 2** 이다.

이유: Slitherlink 의 정답은 단일 폐곡선(simple closed loop). 폐곡선의 모든 꼭짓점은 차수가 짝수이고, 단순 루프이므로 "지나지 않거나(0)", "한 번 들어와서 한 번 나가거나(2)" 둘 중 하나다.

예시 (Square 내부 꼭짓점, 4 변 합류):

```
       │
       │ ←── 위 변
       │
   ─?──•──?─ ← 좌/우 변
       │
       │
       │ ←── 아래 변
```

이 4 변의 합 = 0 또는 2. 1 / 3 / 4 는 절대 불가.

### 1-3. 단일 루프 규칙 (본 문서 범위 밖)
> 그어진 변 전체가 정확히 **하나의** 폐곡선을 이룬다.

작은 분리 루프는 금지. 본 문서의 local propagation 은 이 전역 규칙은 다루지 않는다. 별도의 그래프 분석 단계가 필요하다.

---

## 2. 직접 추론 (Direct Propagation)

라이브 puzzle 상태에서 **즉시** 적용 가능한 규칙들. 다른 추가 가정 없이, 위의 셀/꼭짓점 규칙만으로 결론이 나오는 케이스.

추론은 fixed-point 까지 반복한다 — 한 번의 추론이 새 -1 을 만들면, 그 -1 이 또 다른 추론을 가능케 할 수 있으므로 더 이상 변화 없을 때까지 반복.

### 2-1. 셀 disable 규칙 (둘레 quota 도달)

**조건:** 셀의 active 개수 == num 이고, 미정 변이 1개 이상.

**행동:** 그 셀의 모든 미정 변 → -1.

**왜 그런가:** 이미 num 개를 채웠으니 더 그어선 안 됨. 미정 변은 결국 -1 이 될 운명이므로 미리 마킹.

**예 (Square num=2):**

```
  ┌─1─┐                     ┌─1─┐
  ?   1   ← 2개 active 됨    ─1   1
  └─?─┘   미정 2개 남음       └─-1┘  미정은 모두 -1
```

### 2-2. 꼭짓점 disable 규칙 (분기 금지)

**조건:** 꼭짓점의 active 개수 ≥ 2 이고, 미정 변이 1개 이상.

**행동:** 그 꼭짓점의 모든 미정 변 → -1.

**왜 그런가:** 꼭짓점 차수는 0 또는 2. 이미 2 개가 그어졌으면 추가 변은 차수 3 이상이 되어 규칙 위반. 미정 변은 그어질 수 없으므로 -1.

**예:**

```
       1                        1
       │                        │
   ─?──•──1─    →   ─-1──•──1─
       │                        │
       ?                       -1
```

### 2-3. 꼭짓점 disable 규칙 (데드엔드 — starvation)

**조건:** 꼭짓점의 active 개수 == 0 이고, 미정 변이 정확히 1개.

**행동:** 그 미정 변 → -1.

**왜 그런가:** 꼭짓점 차수가 1 이 되면 규칙 위반(0 또는 2 만 허용). 그러므로 그 마지막 미정 변도 그어질 수 없다.

**예 (꼭짓점에 4 변이 와야 하는데 3 개는 이미 -1, 1 개만 미정):**

```
      -1                      -1
       │                        │
  ─-1──•──?─    →   ─-1──•──-1─
       │                        │
      -1                       -1
```

> **일반화** : `active == 0 and active + undecided < 2` (즉 `undecided == 1`) 이면 disable. `active == 1 and undecided == 0` 은 이미 모순 상태이므로 안전 가드 케이스로 별도 취급 (Section 3-3 참고).

---

## 3. Look-ahead 추론 (1-step Hypothesis)

직접 추론이 fixed-point 에 도달해도 더 이상 결정 안 되는 변은 많이 남는다. 그 중 일부는 실제로는 "그어 봤더니 모순" 이라서 그어질 수 없는 변일 수 있다. 이 케이스를 잡는 게 look-ahead.

핵심 아이디어:
> "각 미정 변마다 한번씩, 만약 이 변을 그었다고 가정해 보자. 그 가정 하에서 직접 추론을 끝까지 돌렸을 때 모순(어느 셀의 active>num 이거나 어느 꼭짓점의 active>2 등)이 나온다면, 그 가정 자체가 틀린 것이다 — 그 변은 절대 그어질 수 없으니 -1 으로 확정."

### 3-1. 가설 시뮬레이션 (Hypothesis Propagation)

가설용 작업 그리드(라이브 puzzle 의 사본)를 만들어 한 변을 1로 세팅하고, 다음 두 규칙을 fixed-point 까지 반복한다. 작업 그리드는 caller 가 snapshot/restore 하므로 시뮬레이션 내부는 자유롭게 변경 가능.

#### A. 셀 규칙 (시뮬레이션 안)

각 셀에 대해 active(=1 인 변 수), undecided(=0 인 변 수) 를 센 뒤:

| 조건 | 행동 | 의미 |
|---|---|---|
| `active > num` | **즉시 모순 반환** | 이미 quota 초과. 가정이 틀렸다. |
| `active + undecided < num` | **즉시 모순 반환** | 남은 변이 부족해서 num 채울 수 없음. 가정이 틀렸다. |
| `active == num and undecided > 0` | 미정 변 모두 -1 | 직접 규칙 2-1 과 동일. |
| `active < num and active + undecided == num and undecided > 0` | **미정 변 모두 1 (force-draw)** | 정확히 부족분만큼 미정이 남았으므로 그것들은 반드시 그어져야 함. |

**force-draw 예 (Square num=3):**

```
  ┌─1─┐                       ┌─1─┐
  ?   1   active=2, un=2,      1   1
  └─?─┘   active+un=4 > num=3  └─?─┘   ← 결정 못 함
```
하지만 만약 한 변이 -1 이 되어 active+un == num 이 되면:
```
  ┌─1─┐                       ┌─1─┐
 -1   1   active=2, un=1,      -1   1
  └─?─┘   active+un=3 == num=3 └─1─┘   ← 미정은 반드시 1 (force-draw)
```

#### B. 꼭짓점 규칙 (시뮬레이션 안)

각 꼭짓점에 대해 active, undecided 를 센 뒤:

| 조건 | 행동 | 의미 |
|---|---|---|
| `active > 2` | **즉시 모순 반환** | 차수 2 초과. 가정이 틀렸다. |
| `active == 1 and undecided == 0` | **즉시 모순 반환** | 차수 1 고정 — 0 도 2 도 될 수 없음. |
| `active >= 2 and undecided > 0` | 미정 변 모두 -1 | 직접 규칙 2-2 와 동일. |
| `active == 0 and undecided == 1` | 미정 변 -1 | 직접 규칙 2-3 와 동일. |
| `active == 1 and undecided == 1` | **미정 변 1 (force-draw)** | 차수 2 가 되어야 하므로 마지막 미정도 반드시 그어진다. |

**Force-draw 예:**
```
       1
       │            (꼭짓점 active=1, undecided=1)
       │
   ─-1──•──?─   →   ─-1──•──1─
       │                  │
      -1                 -1
```

> **중요:** force-draw 결과는 시뮬레이션 내부에서만 1 로 마킹되며, 시뮬레이션 종료 시 caller 가 restore 함. **사용자 puzzle 에는 절대 영구 1 로 기록하지 않는다.** 이유: 자동으로 라인을 그어주면 사용자의 풀이 경험을 망친다.

### 3-2. Look-ahead 메인 루프 (의사 코드)

```
function runLookAhead():
    if not isStateConsistent():
        return false  ← 라이브 상태가 이미 모순이면 스킵 (Section 3-3)

    anyChanged = false
    for each undecided edge e (canonical id 로 중복 제거):
        snapshot = deep copy of working grid
        set e = 1 in working grid
        contradiction = HypothesisPropagation()    ← Section 3-1
        restore working grid from snapshot
        if contradiction:
            set e = -1 (영구)
            anyChanged = true
    return anyChanged
```

새로 -1 이 추가되면 **직접 추론을 다시 한 번 돌려야** 추가 deduction 이 풀린다. 따라서 outer loop 도 fixed-point 까지 반복한다 (상한 5 회 권장 — 보통 1~2 회면 수렴).

```
applyConstraints():
    1. 이전 -1 마킹을 0 으로 클리어 (사용자가 미정으로 되돌릴 수 있어야 함).
    2. 직접 추론 fixed-point.
    3. for laIter in 0..5:
         if not runLookAhead():
             break
         직접 추론 fixed-point
```

### 3-3. 사전 일관성 가드 (안전 장치)

**문제 상황:** 라이브 puzzle 상태가 이미 모순일 때 (예: 사용자가 num=1 셀 둘레에 변을 2 개 그어 둠 — 일반적으로 직접 규칙으로 막히지만, undo / race / 외부 데이터 로드 등으로 일시적으로 가능). 이 상태에서 가설 시뮬레이션을 돌리면 어떤 변에 가설을 세워도 **이미** 모순인 상태에서 시작하므로, 모든 가설이 모순으로 판정되어 **모든 미정 변이 일괄 -1** 처리되는 사고가 난다.

**해결:** look-ahead 패스를 시작하기 전에 라이브 상태를 검사한다.

```
function isStateConsistent():
    for each clue cell:
        if active > num: return false
        if active + undecided < num: return false
    for each vertex:
        if active > 2: return false
        if active == 1 and undecided == 0: return false
    return true
```

조건이 하나라도 걸리면 look-ahead 패스 자체를 건너뛴다. 직접 추론은 영향 없음 (직접 추론은 사용자 활성 변을 건드리지 않으므로 안전).

---

## 4. 사용자 마킹과 propagation (-2, -4 처리)

UI 에는 사용자가 직접 만들 수 있는 두 가지 음수 마킹이 있다.

| 코드 | 어디서 생기나 | 의미 |
|---|---|---|
| `-2` | 자동 비활성(-1) 변을 탭 | "나는 이 -1 에 동의 안 함" — 빨간색 시각 마킹. 변은 여전히 그어지지 않는다. |
| `-4` | 사용자가 그어 둔 활성(≥1) 변을 탭 | X 마킹. 그어지지 않는다는 점은 -1 과 동일하지만 사용자 의지로 잠긴 변. |

### 4-1. 핵심 규칙 — `-2` 는 propagation 의 hard premise 가 되면 안 된다

가장 중요한 항목. **propagation 은 `-2` 를 "확정 비활성" 으로 보면 안 된다.** 보면 다음과 같은 사고가 난다:

> 사용자가 자동 -1 변 `A` 를 탭해 `-2` 로 마킹.
> propagation 이 `A` 를 -1 처럼 취급한 채 look-ahead 진행.
> 어떤 미정 변 `B` 에 대해 가설 `B=1` → 그 가설 안에서 force-draw 로 `A=1` 이 도출됨.
> 하지만 working-grid 의 `A` 는 disabled 로 잠겨 있으므로 `A=1` 은 즉시 모순.
> → `B` 가 영구 -1 로 굳어짐.
> → 사용자 입장에서는 "탭 한 번에 1시 방향의 다른 변까지 비활성화" 사고.

이건 논리적으로도 의심스럽다 — `-2` 는 사용자가 _질문_ 하고 있는 자리이지, 시스템이 새 deduction 의 전제로 삼아도 된다고 동의한 자리가 아니다.

### 4-2. 처리 절차

`applyConstraints` 가 시작될 때:

1. **스냅샷:** `-2` 가 있는 위치 좌표를 모두 기록.
2. **클리어:** `-1` 과 `-2` 를 모두 `0` (미정)으로 되돌린다. (`-4` 는 그대로 — 사용자 X 는 hard 잠금.)
3. **propagation:** Section 2 의 직접 추론 + Section 3 의 look-ahead 를 평소처럼 돌린다. 이 단계에서 `-2` 가 있던 자리는 그냥 미정 변으로 취급되며, propagation 결과로 `-1` 이 다시 도출될 수 있다 (현재 보드 상태가 그것을 정당화하면).
4. **`-2` 복원:** 1 단계 스냅샷의 각 위치에 대해, 현재 값이 `-1` 이면 `-2` 로 복원. 그 외(`0` 이거나 새 deduction 으로 `1+` 이 됐거나)면 그대로 둔다 — 사용자의 빨강 마킹은 _그 자리의 -1_ 에 대한 의문이었으므로, -1 이 사라진 자리에 빨강을 다시 두는 건 의미가 없다.

### 4-3. `-4` 는 hard disable

`-4` (사용자 X) 는 사용자가 명시적으로 잠근 변이므로 propagation 안에서 `-1` 과 동등하게 취급한다. clear 단계에서 `-4` 는 건드리지 않는다. propagation 은 `-4` 를 disabled 로 보고 deduction 을 진행해도 된다 — 사용자가 잠근 자리이므로 그 위에서 새 deduction 이 생기는 건 정상.

### 4-3-1. 그러나 `-4` 가 정답 라인을 잠그면 puzzle 이 globally infeasible 해진다 — global-infeasibility 가드 필요

`-4` 자체는 hard 잠금이지만, 사용자가 정답 라인을 X 처리하면 그 셀이 `num` 을 채울 수 없게 되어 **퍼즐이 globally infeasible** 해진다. 이 상태에서:

- 셀 A 는 `active < num` 이면서 `active + undecided < num` (정답 자리가 -4 로 잠겨서). 즉 LOCAL inconsistency.
- look-ahead 에 진입하기 전에 Section 3-3 의 `isStateConsistent` 가 이걸 잡고 패스 자체를 스킵 — 여기까지는 의도대로.
- 그러나 직접 추론(`_propagateDirect`)은 그보다 먼저 한 번 돌고, 일부 vertex/cell 이 satisfied / starved 상태로 분류되어 cascade 비활성화가 진행된다.
- 다음 outer loop iteration 에서도 같은 직접 추론이 반복되며 cascade 가 더 퍼진다.
- 결과: 보드 대부분 또는 전체가 `-1` 로 도배.

**가드 절차:** `applyConstraints` 진입 시 **전체 edges 그리드의 스냅샷** 을 따로 떠 두고, 모든 propagation (직접 추론 + look-ahead + `-2` 복원) 종료 후 `isStateConsistent` 를 한 번 더 호출. **여전히 false 면** 그 동안의 변경을 모두 버리고 진입 시점 스냅샷으로 되돌린다.

이 revert 의 효과:
- 사용자의 `-4` 마킹은 진입 시점 스냅샷에 이미 들어있었으므로 그대로 살아남는다.
- 직접 추론과 look-ahead 가 일으킨 cascade 비활성화는 모두 사라진다.
- 사용자가 그대로 다시 탭(=`-4` → `0`) 하면 정상 상태 복귀.

**중요:** 이 가드는 Section 3-3 의 사전 일관성 가드(look-ahead 진입 전 검사)와 **별개로 추가**되어야 한다. 사전 가드는 _look-ahead만_ 막고, 직접 추론의 cascade 는 못 막는다. 사후 가드는 propagation 전체의 결과를 검사한다.

### 4-4. propagation 안에서 코드의 분기 정리

| 변 값 | active 카운트에 포함? | undecided 카운트에 포함? | 비활성으로 취급? |
|---|---|---|---|
| `≥ 1` | ✅ | ❌ | ❌ |
| `0` | ❌ | ✅ | ❌ |
| `-1` | ❌ | ❌ | ✅ |
| `-2` | clear 단계 후 propagation 안에서는 존재하지 않음 (모두 0 으로 클리어됨) | | |
| `-4` | ❌ | ❌ | ✅ |

이 표가 풀려고 하는 핵심: **propagation 단계에서 `-2` 를 만나면 안 된다.** 만나면 clear 단계가 빠진 것 — 즉시 fix.

---

## 5. Top-level Flow

호출 시점:
- 사용자가 변을 탭한 직후 (`updateEdge` / `updateSquareBox`).
- Undo / redo / restart 직후.
- Square 의 경우 `checkCurrentPath()` 의 끝에서 호출.
- `HowToPlay` 튜토리얼 스텝.

> **퍼즐 초기화(`init`)에서는 `applyConstraints`(look-ahead)를 돌리지 않는다.**
> init 에서 look-ahead 까지 돌리면 정답에서 강제되는 `-1`/force 라인이 첫 화면에
> 미리 드러나 스포일러가 된다. 따라서 Hexagon/Triangle/Trihex init 은 자명한
> **직접 규칙(`_propagateDirect`)만** 적용하고, Square init 은 그것도 생략해
> 단서만 보여준다. 깊은 추론은 사용자가 첫 변을 두는 순간 `updateEdge` →
> `applyConstraints` 에서 처음 나타난다.

```
applyConstraints():
    0. 전체 edges 그리드 스냅샷 (global-infeasibility revert 용; Section 4-3-1).
    1. -2 위치 스냅샷.
    2. 이전 -1, -2 → 0  (이전 추론 결과 + 사용자 빨강 마킹 클리어; -4 는 그대로)
    3. 직접 추론 fixed-point (Section 2)
    4. Look-ahead loop (Section 3-2)
       - look-ahead 한 바퀴
       - 새 -1 있으면 직접 추론 fixed-point 재돌림
       - 변화 없을 때까지 (상한 5 회)
    5. 1 단계 스냅샷 각 위치의 현재 값이 -1 이면 -2 로 복원.
    6. isStateConsistent() 가 false 면 0 단계 스냅샷으로 전체 revert. 사용자의
       탭 결과(-4 등)는 보존되고 propagation 이 일으킨 cascade 만 차단.
```

---

## 6. 도형별 데이터 구조 차이

규칙 자체는 동일. **차이는 데이터 구조와 꼭짓점 incidence 계산뿐**.

| 항목 | Square | Hexagon | Triangle | Trihex |
|---|---|---|---|---|
| 셀 둘레 변 수 | 4 | 6 | 3 | hex 6 / tri 3 |
| 작업 그리드 | `List<List<int>>` (edge 좌표 — `2*rows+1` 행, 가변 열) | `puzzle[r][c].edges[6]` | `puzzle[r][i].edge0/1/2` | `Map<edgeId, int>` (vertex pair 인코딩) |
| 인접 cell 미러링 | `writeSubmit/readSubmit` | `_neighborEdge(r,c,e)` | `_sharedEdge(r,i,e)` | edge id 가 두 cell 에서 자동 공유 |
| 꼭짓점 incidence | `(vi, vj)` 좌표로 직접 계산 | `_buildVertexIncidence` 캐시 | `_incidentEdges(vr, vi)` | `_edgesByVertex` 맵 |
| 셀 전수 조회 | `(rows, cols)` 이중 루프 | `(rows, cols)` 이중 루프 | `(rows, triPerRow)` 이중 루프 + `isUp` | hex 셀 + 삼각 셀 별도 |
| Pure logic 위치 | `lib/provider/square_propagation_core.dart` (top-level 함수) | Provider 내부 (`_propagateDirect` 등) | Provider 내부 | Provider 내부 |
| 진입점 | `_applyConstraints` ← `applyConstraints` (외부) ← `updateSquareBox` / `HowToPlay.dart` | `_applyConstraints` (내부) | `_applyConstraints` (내부) | `_applyConstraints` (내부) |
| 회귀 테스트 | `test/square_propagation_regression_test.dart` (5 케이스) | 없음 | `test/triangle_model_test.dart` (모델만) | 없음 |

---

## 7. 가상 vs 영구 쓰기 (정리)

| 추론 결과 | 영구 puzzle 에 기록? |
|---|---|
| **disable (-1)** — look-ahead 모순 | **예** (영구). |
| **disable (-1)** — 직접 추론 | **예** (영구). |
| **force-draw (시뮬레이션 1)** | **아니오**. caller 가 restore 시 제거됨. 사용자가 직접 그을 때까지 표시되지 않음. |

force-draw 를 영구 기록하지 않는 이유: **자동으로 라인을 그어주면 사용자 풀이 경험을 망친다**. 사용자가 직접 추론하고 직접 그을 기회를 빼앗지 않는다.

---

## 8. 사용자 표시 정책

- **사용자가 비활성(-1) 변을 클릭** → 빨간색(-2) 으로 잠시 마킹 후 자동 복구. 별도 X 마킹 없음.
- **빨간색(-2) 변은 propagation 의 hard premise 가 아니다** (Section 4-1). 클릭 직후 propagation 은 -2 를 일시적으로 0 으로 보고 돌리며, 결과로 다시 -1 로 도출된 자리에만 -2 를 복원한다.
- **Hidden clue (`num < 0`)** 는 모든 propagator 에서 **무조건 스킵**. 빠뜨리면 한 탭에 보드 전체 비활성화 사고.

---

## 9. 알려진 제한 / 미구현

- **단일 루프 규칙 (Section 1-3)** : 본 문서의 local propagation 은 다루지 않는다. 분리된 작은 루프를 만드는 변이 자동 비활성화되지 않을 수 있다 (전역 그래프 분석 필요).
- **2-step 이상 look-ahead** : 현재는 1-step 만. 깊이 2 이상의 추론은 사용자가 직접 그어 본 뒤 다음 round 의 1-step 으로 잡힌다.
- **꼭짓점-셀 cross 특수 deduction** : "셀 num=3 이고 한 꼭짓점에 외부 변 -1" 같은 도형별 특수 케이스 일부는 직접 / look-ahead 만으로 잡지 못할 수 있음.

---

## 10. 디버깅 체크리스트

코드 리뷰 / 버그 수정 시 체크할 항목:

1. ☐ 라이브 상태 일관성 가드(Section 3-3)가 켜져 있는가? 없으면 한 번의 잘못된 입력으로 보드 전체 비활성화.
2. ☐ Hidden clue (`num < 0`) 가드가 모든 propagator (직접 / 가설 모두) 에 있는가?
3. ☐ `-2` clear/restore (Section 4-2) 가 `applyConstraints` 진입/종료에 들어 있는가? 빠지면 사용자가 -1 을 빨강으로 마킹할 때 1시 방향 등 무관한 변까지 cascade 비활성화.
3-1. ☐ Global-infeasibility revert (Section 4-3-1) 가 `applyConstraints` 종료부에 들어 있는가? 빠지면 사용자가 정답 라인을 X(-4) 처리할 때 직접 추론 cascade 로 보드 전체가 비활성화.
4. ☐ Force-draw 결과가 영구 기록되지 않는가? (가설 시뮬레이션 종료 후 restore 했는가)
5. ☐ 셀 규칙과 꼭짓점 규칙 양쪽에 force-draw 가 누락되지 않았는가?
6. ☐ Outer loop (look-ahead ↔ 직접 추론) 가 fixed-point 까지 도는가? Look-ahead 한 번으로 끝나면 deduction 누락 가능.
7. ☐ 인접 cell 미러링: 변을 -1 / 1 로 바꿀 때 인접 cell 의 같은 변도 함께 갱신했는가?
8. ☐ Snapshot/restore 가 모든 cell × 모든 edge 를 빠짐없이 복원하는가?
