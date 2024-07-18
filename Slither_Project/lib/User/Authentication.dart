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
      await makeDB();
      UserInfo.authState = true;
      await UserInfo.init();
      return 0;
    } catch (e) {
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
      UserInfo.authState = true;
      await UserInfo.init();
      return 0;
    } catch (e) {
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
      return 0;
    } catch (e) {
      return 400;
    }
  }

  Future<int> withdrawEmail(BuildContext context) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.delete();
        UserInfo.authState = false;
        return 0;
      }
    } catch(e) {
      return 400;
    }

    return 400;
  }

  void popup(BuildContext context, String msg) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // 2초 후에 자동으로 닫히는 타이머 설정
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.of(context).pop(true);
        });
        return Dialog(
          backgroundColor: Colors.transparent, // 투명 배경
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFB0E0E6), // SnackBar 배경 색상
              borderRadius: BorderRadius.all(Radius.circular(10.0)),
            ),
            width: screenSize.width * 0.4,
            height: screenSize.height * 0.2,
            child: Center(
              child: Text(
                msg,
                style: const TextStyle(fontSize: 28, color: Colors.black),
                textAlign: TextAlign.center,
              ),
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

  Future<void> makeDB() async {
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
    };

    await db.collection("users").doc(user.email).set(userData).then((_) =>
        print('DocumentSnapshot added with ID: ${user.email}'));
  }
}