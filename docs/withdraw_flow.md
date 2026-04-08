# 회원 탈퇴 흐름

`lib/User/Authentication.dart` 의 `withdrawEmail(context)` 가 즉시 DB + 계정 제거를 수행한다.

## 단계
1. `currentUser` 확인. 없으면 즉시 오류.
2. `deleteDB()` — Firestore `users/{email}` 문서 삭제 (실패해도 다음 단계 진행).
3. `user.delete()` — Firebase Auth 계정 삭제.
4. 로컬 상태 정리:
   - `UserInfo.authState = false`
   - `UserInfo.completed = {}`
   - `UserInfo.continuePuzzle.clear()`
   - `UserInfo.continuePuzzleDate.clear()`
5. `FirebaseAuth.instance.signOut()` (안전망).

## 오류 처리
- `requires-recent-login` → "보안을 위해 최근 로그인이 필요합니다. 로그아웃 후 다시 로그인한 뒤 탈퇴를 시도해주세요."
- 기타 FirebaseAuthException → `_mapAuthError`
- 일반 예외 → "탈퇴 중 오류가 발생했습니다: $e"

## UI
`MainUI.dart` 의 탈퇴 버튼은 빨간 경고 아이콘 확인 다이얼로그로 사용자 의사를 한 번 더 받은 뒤 호출한다.
