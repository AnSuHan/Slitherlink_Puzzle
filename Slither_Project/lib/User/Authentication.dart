import 'package:firebase_auth/firebase_auth.dart' hide UserInfo;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
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
      UserCredential userCredential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      popup(context, "sign up success");
      return 0;
    } catch (e) {
      print(e);
      return 400;
    }
  }

  Future<int> signInEmail(BuildContext context, String email, String password) async {
    if(email.isEmpty || password.isEmpty) {
      return 10;
    }
    try {
      UserCredential userCredential =
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      popup(context, "sign in success");
      return 0;
    } catch (e) {
      print(e);
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
      print(e);
      return 13;
    }
  }

  Future<int> signOutEmail(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      popup(context, "sign out success");
      return 0;
    } catch (e) {
      return 400;
    }
  }

  Future<int> withdrawEmail(BuildContext context) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print("user is not null");
        await user.delete();
        // ignore: use_build_context_synchronously
        popup(context, AppLocalizations.of(context)!.translate('errMsg_Sign07'));
        UserInfo.authState = false;
        return 0;
      }
    } catch(e) {
      print(e);
      return 400;
    }

    return 400;
  }

  void popup(BuildContext context, String msg) {
    Text snack = Text(msg, style: const TextStyle(fontSize: 28, color: Colors.black),);
    Container sizedBox = Container (
      decoration: const BoxDecoration(
        color: Color(0xFFB0E0E6),
      ),
      width: screenSize.width,
      height: screenSize.height * 0.2,
      child: Center(
        child: snack,
      ),
    );
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: sizedBox,
      duration: const Duration(milliseconds: 1000),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(
        left: screenSize.width * 0.3,
        right: screenSize.width * 0.3,
        // ignore: use_build_context_synchronously
        bottom: MediaQuery.of(context).size.height * 0.5, // 화면 중앙에 띄우기
      ),
    ));
  }

  bool isEmail(String input) {
    // RFC 5322에 따른 간단한 이메일 형식 검증
    final emailRegExp =
    RegExp(r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+$', caseSensitive: false);

    return emailRegExp.hasMatch(input);
  }
}