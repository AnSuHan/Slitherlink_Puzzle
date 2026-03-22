// ignore_for_file: file_names
import 'package:firebase_auth/firebase_auth.dart' hide UserInfo;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../User/UserInfo.dart';
import '../firebase_options.dart';
import 'EnterScene.dart';
import '../Platform/ExtractData.dart'
if (dart.library.html) '../Platform/ExtractDataWeb.dart'; // 조건부 import

class Splash extends StatefulWidget {
  const Splash({Key? key}) : super(key: key);

  @override
  SplashState createState() => SplashState();
}

class SplashState extends State<Splash> {
  late Future<void> _initializeSetting;

  @override
  void initState() {
    super.initState();
    _initializeSetting = loading(); // Firebase 초기화 한 번만 호출
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FutureBuilder(
        future: _initializeSetting,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          } else if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Text('Error: ${snapshot.error}'),
              ),
            );
          } else {
            return const EnterScene(); // 초기화 완료 후 EnterScene 표시
          }
        },
      ),
    );
  }

  Future<void> loading() async {
    await firebase();
    await setUserInfo();
    await clearKeys();

    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> firebase() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if(FirebaseAuth.instance.currentUser != null) {
      UserInfo.authState = true;
    }
  }

  Future<void> setUserInfo() async {
    await UserInfo.init();
  }

  Future<void> clearKeys() async {
    //remove SharedPreference's keys | web local storage's keys
    await ExtractData().removeKeyAll();
  }
}