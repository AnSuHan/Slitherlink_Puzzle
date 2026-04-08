// ignore_for_file: file_names
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide UserInfo;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'UserInfo.dart';

/// 10 : 이메일 or 비밀번호 비어 있음
///
/// 11 : 이메일 형식 오류
///
/// 12 : 비밀번호 형식 오류(미사용)
///
/// 13 : 이메일 or 비밀번호가 틀림 - 로그인 시
///
/// 14 : 이메일이 비어 있음 - 비밀번호 찾기 시
///
/// 400 : 서버 오류 - 재시도 요청
///
/// ___
///
/// 1 : 비밀번호 초기화 메일 송신 성공
class Authentication {
  late Size screenSize;

  /// 마지막 인증 에러에 대한 사용자용 메시지 (한국어 기본)
  String lastErrorMessage = '';
  String lastErrorCode = '';

  String _mapAuthError(Object e) {
    if (e is FirebaseAuthException) {
      lastErrorCode = e.code;
      switch (e.code) {
        case 'email-already-in-use':
          return '이미 가입된 이메일입니다. 로그인하거나 다른 이메일을 사용하세요.';
        case 'invalid-email':
          return '이메일 형식이 올바르지 않습니다.';
        case 'operation-not-allowed':
          return '이메일/비밀번호 가입이 비활성화되어 있습니다. 관리자에게 문의하세요. (Firebase 콘솔에서 Email/Password 로그인 활성화 필요)';
        case 'weak-password':
          return '비밀번호가 너무 약합니다. 6자 이상으로 설정하세요.';
        case 'network-request-failed':
          return '네트워크 연결을 확인해주세요.';
        case 'too-many-requests':
          return '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.';
        case 'user-disabled':
          return '비활성화된 계정입니다.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return '이메일 또는 비밀번호가 올바르지 않습니다.';
        default:
          return '인증 오류: ${e.message ?? e.code}';
      }
    }
    lastErrorCode = 'unknown';
    return '알 수 없는 오류: $e';
  }

  void setScreenSize(Size size) {
    screenSize = size;
  }

  Future<int> signUpEmail(BuildContext context, String email, String password) async {
    if(email.isEmpty || password.isEmpty) {
      return 10;
    }
    else if(!isEmail(email)) {
      return 11;
    }

    try {
      lastErrorMessage = '';
      lastErrorCode = '';
      // 회원가입 직전 비로그인 상태에서 쌓인 로컬 완료 이력을 캡처해 새 계정으로 이관
      final Map<String, int> migrating = Map<String, int>.from(UserInfo.completed);
      UserCredential userCredential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await makeDB(initialCompleted: migrating);
      // 로컬 저장본은 비워서 다음 비로그인 세션에 잔존하지 않도록 함
      await UserInfo.clearLocalCompleted();
      UserInfo.authState = true;
      await UserInfo.init();
      return 0;
    } catch (e) {
      // ignore: avoid_print
      print('signUpEmail error: $e');
      lastErrorMessage = _mapAuthError(e);
      return 400;
    }
  }

  Future<int> signInEmail(BuildContext context, String email, String password) async {
    if(email.isEmpty || password.isEmpty) {
      return 10;
    }
    try {
      lastErrorMessage = '';
      lastErrorCode = '';
      UserCredential userCredential =
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // 비로그인 상태에서 쌓인 로컬 이력은 초기화
      await UserInfo.clearLocalCompleted();
      UserInfo.completed = {};
      UserInfo.authState = true;
      await UserInfo.init();
      return 0;
    } catch (e) {
      // ignore: avoid_print
      print('signInEmail error: $e');
      lastErrorMessage = _mapAuthError(e);
      return 13;
    }
  }

  Future<int> resetPasswordEmail(BuildContext context, String email) async {
    if(email.isEmpty) {
      return 14;
    }
    else if(!isEmail(email)) {
      return 11;
    }
    try {
      await FirebaseAuth.instance.setLanguageCode(Intl.getCurrentLocale());  //set email language
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: email);
      return 1;
    } catch(e) {
      return 13;
    }
  }

  Future<int> signOutEmail(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      UserInfo.authState = false;
      // 로그아웃 시 완료 이력은 화면에 노출되지 않도록 메모리/로컬 모두 정리
      UserInfo.completed = {};
      await UserInfo.clearLocalCompleted();
      return 0;
    } catch (e) {
      return 400;
    }
  }

  Future<int> withdrawEmail(BuildContext context) async {
    try {
      lastErrorMessage = '';
      lastErrorCode = '';
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        lastErrorMessage = '로그인된 계정이 없습니다.';
        return 400;
      }
      // Firestore 문서 먼저 삭제
      try {
        await deleteDB();
      } catch (e) {
        // ignore: avoid_print
        print('deleteDB during withdraw failed: $e');
      }
      // Firebase 계정 삭제
      await user.delete();
      // 로컬 상태 정리
      UserInfo.authState = false;
      UserInfo.completed = {};
      UserInfo.continuePuzzle.clear();
      UserInfo.continuePuzzleDate.clear();
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
      return 0;
    } on FirebaseAuthException catch (e) {
      // ignore: avoid_print
      print('withdrawEmail FirebaseAuthException: ${e.code} ${e.message}');
      if (e.code == 'requires-recent-login') {
        lastErrorMessage = '보안을 위해 최근 로그인이 필요합니다. 로그아웃 후 다시 로그인한 뒤 탈퇴를 시도해주세요.';
      } else {
        lastErrorMessage = _mapAuthError(e);
      }
      return 400;
    } catch (e) {
      // ignore: avoid_print
      print('withdrawEmail error: $e');
      lastErrorMessage = '탈퇴 중 오류가 발생했습니다: $e';
      return 400;
    }
  }

  void popup(BuildContext context, String msg) {
    // 사용자가 직접 닫는 완료 다이얼로그. 닫으면 호출 화면(메인)으로 돌아간다.
    // 자동 닫힘 + 잘못된 context.pop 으로 메인으로 못 돌아가던 문제 수정.
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        final isDark = MediaQuery.of(dialogContext).platformBrightness == Brightness.dark;
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1E1E3A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 56,
                  color: isDark ? const Color(0xFF80E0B0) : const Color(0xFF2E7D32),
                ),
                const SizedBox(height: 16),
                Text(
                  msg,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF3949AB) : const Color(0xFF5C6BC0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('OK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool isEmail(String input) {
    // RFC 5322에 따른 간단한 이메일 형식 검증
    final emailRegExp =
    RegExp(r'^[a-zA-Z\d.]+@[a-zA-Z\d]+\.[a-zA-Z]+$', caseSensitive: false);

    return emailRegExp.hasMatch(input);
  }

  Future<void> makeDB({Map<String, int>? initialCompleted}) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    User user = FirebaseAuth.instance.currentUser!;

    final account = <String, dynamic> {
      "email": user.email,
    };

    final progress = <String, dynamic> {
      "square_small": 0,
      "triangle_small": 0,
    };

    final userData = {
      "account": account,
      "progress": progress,
      "completed": initialCompleted ?? <String, int>{},
    };

    await db.collection("users").doc(user.email).set(userData).then((_) =>
        // ignore: avoid_print
        print('DocumentSnapshot added with ID: ${user.email}'));
  }

  Future<int> deleteDB() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        FirebaseFirestore db = FirebaseFirestore.instance;

        await db.collection("users").doc(user.email).delete().then((_) {
          // ignore: avoid_print
          print("User document with email ${user.email} deleted from Firestore.");
        }).catchError((error) {
          // ignore: avoid_print
          print("Failed to delete user document: $error");
          throw Exception("Failed to delete user document");
        });

        return 0;
      }
    } catch (e) {
      // ignore: avoid_print
      print("Error during withdrawal: $e");
      throw Exception("Database deletion failed");
    }

    return 400;
  }
}