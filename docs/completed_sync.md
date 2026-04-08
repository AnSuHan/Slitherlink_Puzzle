# 완료 이력 저장/동기화 정책

비로그인·로그인 상태에 따라 퍼즐 완료 카운트(`UserInfo.completed`) 의 저장 위치가 달라지며, 로그인/회원가입/로그아웃 시 이관 규칙을 따른다.

## 상태별 저장 위치
| 상태 | 메모리 | 로컬(SharedPreferences) | Firestore `users/{email}.completed` |
|---|---|---|---|
| 비로그인 | 표시 O | 저장 O | - |
| 로그인 | 표시 O | 저장 X (정리됨) | 저장 O (merge) |
| 로그아웃 직후 | 비움 | 비움 | 그대로 유지 |

## 카테고리 키 생성
`UserInfo.incrementCompleted(loadKey)` 가 `loadKey` 를 분해해 카테고리를 만든다.
- 일반 퍼즐: `${shape}_${size}` (예: `square_small`)
- 생성 퍼즐: 토큰[1] == "generate" 인 경우 `${shape}_${rowsXcols}` (예: `square_10x10`)

## 이벤트 흐름
- **회원가입 (signUpEmail)**: 가입 직전 `UserInfo.completed` 스냅샷을 캡처 → `makeDB(initialCompleted: ...)` 로 새 문서 생성 → `clearLocalCompleted()` → `init()` 으로 재로드.
- **로그인 (signInEmail)**: 비로그인 이력은 폐기 (`clearLocalCompleted()` + 메모리 비움) → `init()` 가 Firestore 의 값으로 덮어씀.
- **로그아웃 (signOutEmail)**: 메모리 + 로컬 모두 비움 (UI 에서 보이지 않게).
- **탈퇴 (withdrawEmail)**: `deleteDB()` (Firestore 문서 삭제) → `user.delete()` → 로컬 정리.

## Firestore 문서 구조
```
users/{email}
  account: { email }
  progress: { square_small, triangle_small }
  completed: { "<category>": <int>, ... }
```

## 관련 파일
- `lib/User/UserInfo.dart` — `init`, `saveCompleted`, `loadCompleted`, `clearLocalCompleted`, `incrementCompleted`
- `lib/User/Authentication.dart` — `signUpEmail`, `signInEmail`, `signOutEmail`, `withdrawEmail`, `makeDB`, `deleteDB`
