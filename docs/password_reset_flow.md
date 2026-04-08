# 비밀번호 재설정 메일 인증 흐름

## 개요
Firebase 의 `sendPasswordResetEmail` 을 사용한다. 별도의 OTP 서버는 없으며, Firebase 가 메일로 oobCode 가 포함된 호스팅 페이지 링크를 발송한다. 사용자는 그 페이지에서 새 비밀번호를 입력하여 검증·적용한다.

## 코드 위치
- `lib/User/Authentication.dart` → `resetPasswordEmail(context, email)`
- `lib/widgets/MainUI.dart` → 로그인 다이얼로그의 "비밀번호 재설정" 버튼

## 단계
1. 사용자가 로그인 다이얼로그에서 이메일 입력 후 "비밀번호 재설정" 클릭.
2. 클라이언트 검증: 빈 값 / 이메일 형식 (`isEmail`).
3. 확인 다이얼로그(mark_email_unread 아이콘)로 발송 대상 이메일을 다시 보여주고 사용자가 "전송" 승인.
4. `FirebaseAuth.instance.setLanguageCode(Intl.getCurrentLocale())` 호출로 메일 언어 설정.
5. `sendPasswordResetEmail(email: ...)` 호출.
6. Firebase 가 oobCode 가 들어간 링크를 메일로 발송 → 사용자가 링크 클릭 → Firebase 호스팅 페이지에서 새 비밀번호 입력 → 검증/적용.
7. 클라이언트는 성공 시 "비밀번호 재설정 메일을 보냈습니다." 팝업을 띄우고 로그인 다이얼로그를 닫는다.

## 오류 처리
- `user-not-found` → "해당 이메일로 가입된 계정이 없습니다." (별도 분기)
- 그 외 `FirebaseAuthException` → `_mapAuthError` 사용
- 일반 예외 → "재설정 메일 전송 중 오류가 발생했습니다: $e"

## 보안 노트
인증 자체는 Firebase 메일함 소유 증명에 위임된다. 앱은 oobCode 검증/비밀번호 변경 로직을 들고 있지 않다.
