// ignore_for_file: file_names
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../firebase_options.dart';
import 'EnterScene.dart';

class Splash extends StatefulWidget {
  const Splash({Key? key}) : super(key: key);

  @override
  SplashState createState() => SplashState();
}

class SplashState extends State<Splash> {
  late Future<void> _initializeFirebase;

  @override
  void initState() {
    super.initState();
    _initializeFirebase = firebase(); // Firebase 초기화 한 번만 호출
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FutureBuilder(
        future: _initializeFirebase,
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

  Future<void> firebase() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}