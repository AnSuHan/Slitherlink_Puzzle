# Firebase Auth 오류 매핑

`lib/User/Authentication.dart` 의 `_mapAuthError(Object e)` 가 `FirebaseAuthException.code` 를 한국어 메시지로 변환한다. 결과는 `lastErrorMessage` / `lastErrorCode` 에 저장되어 UI 에서 표시된다.

## 매핑 표

| code | 메시지 |
|---|---|
| email-already-in-use | 이미 가입된 이메일입니다. 로그인하거나 다른 이메일을 사용하세요. |
| invalid-email | 이메일 형식이 올바르지 않습니다. |
| operation-not-allowed | 이메일/비밀번호 가입이 비활성화되어 있습니다. (Firebase 콘솔에서 Email/Password 활성화 필요) |
| weak-password | 비밀번호가 너무 약합니다. 6자 이상으로 설정하세요. |
| network-request-failed | 네트워크 연결을 확인해주세요. |
| too-many-requests | 요청이 너무 많습니다. 잠시 후 다시 시도해주세요. |
| user-disabled | 비활성화된 계정입니다. |
| user-not-found / wrong-password / invalid-credential | 이메일 또는 비밀번호가 올바르지 않습니다. |
| requires-recent-login | (탈퇴시) 보안을 위해 최근 로그인이 필요합니다. |

## 사용 위치
- `signUpEmail`, `signInEmail`, `resetPasswordEmail`, `withdrawEmail` 모두 catch 블록에서 호출.
- `MainUI.dart` 로그인 다이얼로그가 `auth.lastErrorMessage` 를 fallback 으로 표시.
